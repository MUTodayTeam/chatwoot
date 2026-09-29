require 'rails_helper'

RSpec.describe Custom::MessageFinder do
  let(:conversation) { create(:conversation) }
  let(:message_attributes) { { account: conversation.account, inbox: conversation.inbox, conversation: conversation } }

  it 'returns every activity of the conversation, oldest first, past the page the thread loads' do
    activities = Array.new(3) { create(:message, message_type: :activity, **message_attributes) }
    create_list(:message, 25, message_type: :incoming, **message_attributes)

    expect(MessageFinder.new(conversation, { activity_only: 'true' }).perform.map(&:id)).to eq(activities.map(&:id))
  end

  it 'keeps the latest activities once there are more than the limit' do
    stub_const('Custom::MessageFinder::ACTIVITY_LIMIT', 2)
    activities = Array.new(3) { create(:message, message_type: :activity, **message_attributes) }

    expect(MessageFinder.new(conversation, { activity_only: 'true' }).perform.map(&:id)).to eq(activities.last(2).map(&:id))
  end

  it 'leaves the paged thread as it is without the param' do
    create_list(:message, 25, message_type: :incoming, **message_attributes)

    expect(MessageFinder.new(conversation, {}).perform.size).to eq(20)
  end
end
