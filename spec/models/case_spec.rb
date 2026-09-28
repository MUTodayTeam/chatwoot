require 'rails_helper'

RSpec.describe Case do
  let(:account) { create(:account) }
  let(:project) { account.projects.create!(name: 'Checkin+', code: 'CK') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '.ensure_for!' do
    before do
      create(:message, account: account, conversation: conversation, message_type: :incoming,
                       content: "  My booking\n for tonight is missing from the app, please help  ")
      create(:message, account: account, conversation: conversation, message_type: :incoming, content: 'Hello?')
    end

    it 'opens the case with the next number, the project, the first incoming message and a low severity' do
      create(:case, conversation: create(:conversation, account: account), display_id: 857)

      kase = described_class.ensure_for!(conversation, agent)

      expect(kase).to have_attributes(
        account_id: account.id, project_id: project.id, display_id: 858, severity: 'p4', reopened_count: 0,
        subject: 'My booking for tonight is missing from the ap...'
      )
      expect(kase.display).to eq('#CK-858')
    end

    it "files the case under the agent's first team" do
      teams = create_list(:team, 2, account: account)
      teams.reverse_each { |team| create(:team_member, team: team, user: agent) }
      create(:team_member, team: create(:team), user: agent)

      expect(described_class.ensure_for!(conversation, agent).team_id).to eq(teams.first.id)
    end

    it 'writes the activity message once however often it is called' do
      2.times { described_class.ensure_for!(conversation, agent) }

      expect(described_class.where(conversation: conversation).count).to eq(1)
      expect(conversation.messages.activity.pluck(:content)).to eq(['Case #CK-1 opened automatically'])
    end

    it 'returns the case another worker created first' do
      existing = create(:case, conversation: conversation)
      lookups = 0
      # The first lookup misses, as it would for a worker that raced the one that won
      allow(described_class).to(receive(:find_by).and_wrap_original { |original, *args| (lookups += 1) == 1 ? nil : original.call(*args) })

      expect(described_class.ensure_for!(conversation, agent)).to eq(existing)
    end
  end

  # Each thread needs its own database connection for the lock to matter, so this runs outside
  # the per-example transaction and removes what it wrote.
  describe '.ensure_for! under concurrent workers' do
    self.use_transactional_tests = false

    after do
      models = [described_class, Message, Conversation, Contact, Channel::WebWidget, WorkingHour, Inbox, NotificationSetting, AccountUser, Project]
      models.each { |model| model.where(account_id: account.id).delete_all }
      ContactInbox.where(inbox_id: inbox.id).delete_all
      Audited::Audit.where(associated_type: 'Account', associated_id: account.id).delete_all
      AccessToken.where(owner: agent).delete_all
      agent.delete
      account.delete
    end

    it 'numbers the cases of one account without gaps or duplicates and opens one per conversation' do
      conversations = create_list(:conversation, 4, account: account, inbox: inbox)
      targets = conversations + [conversations.first]
      barrier = Concurrent::CyclicBarrier.new(targets.size)
      threads = targets.map do |target|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.wait
            described_class.ensure_for!(target, agent)
          end
        end
      end
      threads.each(&:join)

      expect(described_class.where(account_id: account.id).order(:display_id).pluck(:display_id)).to eq([1, 2, 3, 4])
    end
  end

  describe '#display' do
    it 'falls back to the bare number without a project code' do
      expect(build(:case, display_id: 12).display).to eq('#12')
    end
  end

  describe 'validations' do
    it 'rejects a team from another account' do
      kase = build(:case, conversation: conversation, team: create(:team))

      expect(kase).not_to be_valid
      expect(kase.errors[:team_id]).to be_present
    end

    it 'rejects an unknown severity' do
      expect(build(:case, conversation: conversation, severity: 'p9')).not_to be_valid
    end
  end
end
