require 'rails_helper'

describe CaseListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }

  describe '#assignee_changed' do
    let(:event) { Events::Base.new(:assignee_changed, Time.zone.now, conversation: conversation) }

    it 'opens one case even when the event arrives twice' do
      2.times { listener.assignee_changed(event) }

      expect(Case.where(conversation: conversation).count).to eq(1)
      expect(conversation.messages.activity.where(content: 'Case #1 opened automatically').count).to eq(1)
    end

    it 'leaves a conversation without an agent alone' do
      conversation.update!(assignee: nil)

      listener.assignee_changed(event)

      expect(Case.where(conversation: conversation)).not_to exist
    end

    it 'opens the case whichever path assigns the agent' do
      unassigned = create(:conversation, account: account)

      perform_enqueued_jobs(only: EventDispatcherJob) { unassigned.update!(assignee: agent) }

      expect(unassigned.reload.case).to be_present
    end
  end

  describe '#conversation_updated' do
    let!(:kase) { create(:case, conversation: conversation) }

    def status_changed(from, to = 'open')
      Events::Base.new(:conversation_updated, Time.zone.now, conversation: conversation, changed_attributes: { 'status' => [from, to] })
    end

    it 'counts a reopen after Solved or Closed' do
      listener.conversation_updated(status_changed('resolved'))
      listener.conversation_updated(status_changed('closed'))

      expect(kase.reload.reopened_count).to eq(2)
    end

    it 'does not count leaving pending or hold, or closing' do
      listener.conversation_updated(status_changed('pending'))
      listener.conversation_updated(status_changed('snoozed'))
      listener.conversation_updated(status_changed('resolved', 'closed'))
      listener.conversation_updated(Events::Base.new(:conversation_updated, Time.zone.now, conversation: conversation))

      expect(kase.reload.reopened_count).to eq(0)
    end

    it 'counts the reopen a customer message triggers on a resolved conversation' do
      conversation.resolved!

      perform_enqueued_jobs(only: EventDispatcherJob) { create(:message, account: account, conversation: conversation, message_type: :incoming) }

      expect(conversation.reload).to be_open
      expect(kase.reload.reopened_count).to eq(1)
    end
  end
end
