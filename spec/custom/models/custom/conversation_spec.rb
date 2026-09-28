require 'rails_helper'

RSpec.describe Custom::Conversation do
  let(:conversation) { create(:conversation) }

  after do
    Current.user = nil
    Current.executed_by = nil
  end

  describe 'leaving the closed status' do
    before { conversation.update!(status: :closed) }

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
    it 'does not emit conversation_resolved again after it was resolved' do
      conversation.update!(status: :resolved)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      conversation.update!(status: :closed)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch).with(Conversation::CONVERSATION_RESOLVED, any_args)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(Conversation::CONVERSATION_STATUS_CHANGED, any_args)
    end

    it 'stops waiting on a reply' do
      expect(conversation.waiting_since).to be_present

      conversation.update!(status: :closed)

      expect(conversation.reload).to have_attributes(waiting_since: nil, reply_due_at: nil)
    end

    it 'records who closed it' do
      agent = create(:user, account: conversation.account)
      Current.user = agent

      expect { conversation.update!(status: :closed) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                              content: "Conversation was closed by #{agent.name}",
                              content_attributes: { activity: { type: 'conversation_status_changed', status: 'closed' } } })
    end
  end
end
