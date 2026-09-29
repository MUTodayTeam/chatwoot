require 'rails_helper'

describe ConversationHandlerListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:toon) { create(:user, account: account, role: :agent, name: 'Toon') }
  let(:poy) { create(:user, account: account, role: :agent, name: 'Poy') }
  let(:conversation) { create(:conversation, account: account) }
  let(:handlers) { ConversationHandler.where(conversation: conversation).order(:started_at, :id) }

  def event(name, **data)
    Events::Base.new(name, Time.zone.now, conversation: conversation, **data)
  end

  it 'runs on the sync dispatcher, so turns follow the order of the commits' do
    expect(SyncDispatcher.new.listeners).to include(listener)
    expect(AsyncDispatcher.new.listeners).not_to include(listener)
  end

  describe '#assignee_changed' do
    it 'opens a turn for the agent the conversation is assigned to' do
      conversation.update!(assignee: toon)

      expect(handlers.pluck(:user_id, :ended_at)).to eq([[toon.id, nil]])
    end

    it 'ends the previous agent\'s turn as an assign, by whoever reassigned it, and opens the next' do
      conversation.update!(assignee: toon)
      Current.user = poy
      conversation.update!(assignee: poy)

      expect(handlers.map { |handler| [handler.user_id, handler.end_reason, handler.ended_by_id] })
        .to eq([[toon.id, 'assign', poy.id], [poy.id, nil, nil]])
    ensure
      Current.reset
    end

    it 'ends the turn as unassigned when nobody takes over' do
      conversation.update!(assignee: toon)
      conversation.update!(assignee: nil)

      expect(handlers.pluck(:end_reason)).to eq(['unassigned'])
      expect(handlers.open).not_to exist
    end

    it 'keeps one open turn when the event arrives twice' do
      conversation.update!(assignee: toon)
      2.times { listener.assignee_changed(event(:assignee_changed)) }

      expect(handlers.pluck(:user_id, :end_reason)).to eq([[toon.id, nil]])
    end

    it 'opens no turn on a Solved conversation' do
      conversation.update!(status: :resolved)
      conversation.update!(assignee: toon)

      expect(handlers).not_to exist
    end
  end

  describe '#conversation_resolved' do
    before { conversation.update!(assignee: toon) }

    it 'ends the open turn as Solved' do
      conversation.update!(status: :resolved)

      expect(handlers.pluck(:user_id, :end_reason)).to eq([[toon.id, 'solved']])
      expect(handlers.first.ended_at).to be_present
    end

    it 'leaves a turn a synchronous close already ended with its own reason' do
      ConversationHandler.close_open!(conversation, reason: :auto_solved)
      conversation.update!(status: :resolved)
      listener.conversation_resolved(event(:conversation_resolved))

      expect(handlers.pluck(:end_reason)).to eq(['auto_solved'])
    end
  end

  describe '#conversation_updated' do
    before do
      conversation.update!(assignee: toon)
      conversation.update!(status: :resolved)
    end

    it 'opens a new turn for the assignee when a Solved conversation reopens' do
      conversation.update!(status: :open)

      expect(handlers.pluck(:user_id, :end_reason)).to eq([[toon.id, 'solved'], [toon.id, nil]])
    end

    it 'opens a new turn when a Closed conversation reopens' do
      conversation.update!(status: :closed)
      conversation.update!(status: :open)

      expect(handlers.open.pluck(:user_id)).to eq([toon.id])
    end

    it 'opens one turn when a reopen also changes the assignee, whichever event comes first' do
      conversation.update!(status: :open, assignee: poy)
      listener.conversation_updated(event(:conversation_updated, changed_attributes: { 'status' => %w[resolved open] }))

      expect(handlers.pluck(:user_id, :end_reason)).to eq([[toon.id, 'solved'], [poy.id, nil]])
    end

    it 'does nothing for a change that is not a reopen' do
      listener.conversation_updated(event(:conversation_updated, changed_attributes: { 'status' => %w[resolved closed] }))
      listener.conversation_updated(event(:conversation_updated, changed_attributes: { 'priority' => [nil, 'high'] }))

      expect(handlers.open).not_to exist
    end
  end
end
