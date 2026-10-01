require 'rails_helper'

RSpec.describe Custom::Conversation do
  let(:conversation) { create(:conversation) }

  after do
    Current.user = nil
    Current.executed_by = nil
  end

  describe 'leaving the closed status' do
    before { conversation.tap(&:resolved!).closed! }

    it 'allows reopening' do
      expect(conversation.update(status: :open)).to be(true)
    end

    it 'reopens on toggle' do
      conversation.toggle_status

      expect(conversation.reload).to be_open
    end

    it 'refuses any other status' do
      %i[resolved pending snoozed].each do |status|
        expect(conversation.reload.update(status: status)).to be(false)
        expect(conversation.errors[:status]).to include('can only change from closed by reopening the conversation')
      end
    end
  end

  describe 'closing a conversation' do
    it 'only closes a resolved conversation' do
      %i[open pending snoozed].each do |status|
        conversation.update!(status: status)

        expect(conversation.update(status: :closed)).to be(false)
        expect(conversation.errors[:status]).to include('can only be closed after the conversation is resolved')
      end
    end

    it 'refuses to create a closed conversation' do
      expect(build(:conversation, status: :closed)).not_to be_valid
    end

    it 'does not emit conversation_resolved again after it was resolved' do
      conversation.update!(status: :resolved)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      conversation.update!(status: :closed)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(Conversation::CONVERSATION_RESOLVED, any_args)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(Conversation::CONVERSATION_STATUS_CHANGED, any_args)
    end

    it 'records who closed it' do
      conversation.update!(status: :resolved)
      agent = create(:user, account: conversation.account)
      Current.user = agent

      expect { conversation.update!(status: :closed) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                              content: "Conversation was closed by #{agent.name}",
                              content_attributes: { activity: { type: 'conversation_status_changed', status: 'closed' } } })
    end
  end

  describe 'muting a closed conversation' do
    it 'blocks the contact and keeps the conversation closed' do
      conversation.tap(&:resolved!).closed!

      conversation.mute!

      expect(conversation.contact.reload).to be_blocked
      expect(conversation.reload).to be_closed
    end
  end

  describe 'automatic assignment and a developer' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
    let(:developer) { create(:user, account: account, role: :agent) }

    before do
      create(:inbox_member, inbox: inbox, user: developer)
      developer.account_users.first.update!(auto_offline: false, availability: :online, developer: true)
      inbox.reload
    end

    it 'leaves a new conversation unassigned when only a developer is online' do
      expect(create(:conversation, account: account, inbox: inbox).assignee).to be_nil
    end

    it 'leaves a conversation unassigned when its team is picked and only a developer is on it' do
      team = create(:team, account: account, allow_auto_assign: true)
      create(:team_member, team: team, user: developer)
      conversation = create(:conversation, account: account, inbox: inbox)

      conversation.update!(team: team)

      expect(conversation.reload.assignee).to be_nil
    end
  end
end
