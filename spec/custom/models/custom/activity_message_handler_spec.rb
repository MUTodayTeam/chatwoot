require 'rails_helper'

RSpec.describe Custom::ActivityMessageHandler do
  let(:conversation) { create(:conversation) }

  after { Current.executed_by = nil }

  it 'names the system when the live chat rules change the status' do
    conversation.update!(status: :resolved)
    Current.executed_by = conversation.account.live_chat_rules.create!

    expect { conversation.update!(status: :closed) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                            content: 'Conversation was closed by Automation System',
                            content_attributes: { activity: { type: 'conversation_status_changed', status: 'closed' } } })
  end

  it 'keeps the automation rule copy' do
    conversation.update!(status: :resolved)
    Current.executed_by = create(:automation_rule, account: conversation.account)

    expect { conversation.update!(status: :closed) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Conversation was closed by Automation System'))
  end
end
