require 'rails_helper'

# The clocks under test are timestamps the callbacks own, so the examples set them directly.
# rubocop:disable Rails/SkipsModelValidations
RSpec.describe LiveChatRules::SweepJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  it 'runs every minute on the scheduled jobs queue' do
    schedule = YAML.load_file(Rails.root.join('config/schedule.yml'))['live_chat_rules_sweep_job']

    expect(schedule).to include('cron' => '*/1 * * * *', 'class' => described_class.name, 'queue' => 'scheduled_jobs')
  end

  it 'saves the account default rule it runs under' do
    expect { described_class.perform_now }.to change { account.live_chat_rules.where(project_id: nil).count }.from(0).to(1)
  end

  describe 'missed' do
    it 'flags an open conversation nobody picked up within the waiting time, once' do
      conversation.update_columns(created_at: 61.minutes.ago)

      described_class.perform_now
      missed_at = conversation.reload.missed_at
      travel(1.minute) { described_class.perform_now }

      expect(missed_at).to be_present
      expect(conversation.reload.missed_at).to be_within(1.second).of(missed_at)
    end

    it 'leaves a conversation that is still within the waiting time' do
      conversation.update_columns(created_at: 59.minutes.ago)

      described_class.perform_now

      expect(conversation.reload.missed_at).to be_nil
    end

    it 'leaves a conversation that an agent picked up' do
      conversation.update_columns(created_at: 2.hours.ago, assignee_id: create(:user, account: account).id)

      described_class.perform_now

      expect(conversation.reload.missed_at).to be_nil
    end

    it 'leaves a conversation that an agent replied to' do
      conversation.update_columns(created_at: 2.hours.ago, first_reply_created_at: 90.minutes.ago)

      described_class.perform_now

      expect(conversation.reload.missed_at).to be_nil
    end
  end

  describe 'expired' do
    it 'flags an open conversation past its reply deadline, once' do
      conversation.update_columns(waiting_since: 2.hours.ago, reply_due_at: 1.minute.ago)

      described_class.perform_now
      expired_at = conversation.reload.expired_at
      travel(1.minute) { described_class.perform_now }

      expect(expired_at).to be_present
      expect(conversation.reload.expired_at).to be_within(1.second).of(expired_at)
    end

    it 'leaves a conversation that is still within its deadline' do
      conversation.update_columns(waiting_since: 10.minutes.ago, reply_due_at: 50.minutes.from_now)

      described_class.perform_now

      expect(conversation.reload.expired_at).to be_nil
    end

    it 'leaves a pending conversation past its deadline' do
      conversation.update_columns(status: Conversation.statuses[:pending], waiting_since: 2.hours.ago, reply_due_at: 1.minute.ago)

      described_class.perform_now

      expect(conversation.reload.expired_at).to be_nil
    end
  end

  describe 'auto-solve' do
    before { conversation.update!(status: :pending) }

    it 'resolves a conversation pending for longer than auto_solve_hours, once' do
      conversation.update_columns(status_changed_at: 25.hours.ago)

      expect { 2.times { described_class.perform_now } }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: 'Conversation was marked resolved by system after 24 hours in pending'))
        .exactly(:once)
      expect(conversation.reload).to be_resolved
    end

    it 'leaves a conversation that has not been pending that long' do
      conversation.update_columns(status_changed_at: 23.hours.ago)

      described_class.perform_now

      expect(conversation.reload).to be_pending
    end

    it 'leaves a conversation that is with an agent bot' do
      conversation.update_columns(status_changed_at: 25.hours.ago, assignee_agent_bot_id: create(:agent_bot).id, ai_assignee_type: 'AgentBot')

      described_class.perform_now

      expect(conversation.reload).to be_pending
    end

    it 'leaves a conversation in an inbox that has a bot' do
      create(:agent_bot_inbox, inbox: inbox)
      conversation.update_columns(status_changed_at: 25.hours.ago)

      described_class.perform_now

      expect(conversation.reload).to be_pending
    end
  end

  describe 'auto-close' do
    before { conversation.update!(status: :resolved) }

    it 'closes a conversation resolved for longer than auto_close_hours, once' do
      conversation.update_columns(status_changed_at: 49.hours.ago)

      expect { 2.times { described_class.perform_now } }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: 'Conversation was closed by system 48 hours after it was resolved'))
        .exactly(:once)
      expect(conversation.reload).to be_closed
    end

    it 'leaves a conversation that has not been resolved that long' do
      conversation.update_columns(status_changed_at: 47.hours.ago)

      described_class.perform_now

      expect(conversation.reload).to be_resolved
    end
  end

  it 'closes a conversation it auto-solved only after auto_close_hours more' do
    conversation.update!(status: :pending)
    conversation.update_columns(status_changed_at: 25.hours.ago)

    described_class.perform_now
    travel(47.hours) { described_class.perform_now }
    expect(conversation.reload).to be_resolved

    travel(49.hours) { described_class.perform_now }
    expect(conversation.reload).to be_closed
  end

  describe 'project overrides' do
    let(:project) { account.projects.create!(name: 'Project A') }
    let(:project_inbox) { create(:inbox, account: account, project: project) }
    let(:project_conversation) { create(:conversation, account: account, inbox: project_inbox) }

    before do
      account.live_chat_rules.create!(project: project, waiting_time_minutes: 10, auto_solve_hours: 2, auto_close_hours: 3)
      [conversation, project_conversation].each { |c| c.update!(status: :pending) }
    end

    it "uses the project's own rule for its inboxes and the account default elsewhere" do
      [conversation, project_conversation].each { |c| c.update_columns(status_changed_at: 150.minutes.ago) }

      described_class.perform_now

      expect(project_conversation.reload).to be_resolved
      expect(conversation.reload).to be_pending
    end

    it 'names the hours of the rule that moved the conversation' do
      project_conversation.update_columns(status_changed_at: 150.minutes.ago)

      expect { described_class.perform_now }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(project_conversation, hash_including(content: 'Conversation was marked resolved by system after 2 hours in pending'))
    end

    it "flags missed on the project's waiting time" do
      [conversation, project_conversation].each { |c| c.update_columns(status: Conversation.statuses[:open], created_at: 15.minutes.ago) }

      described_class.perform_now

      expect(project_conversation.reload.missed_at).to be_present
      expect(conversation.reload.missed_at).to be_nil
    end
  end

  it 'leaves Current.executed_by unset afterwards' do
    described_class.perform_now

    expect(Current.executed_by).to be_nil
  end
end
# rubocop:enable Rails/SkipsModelValidations
