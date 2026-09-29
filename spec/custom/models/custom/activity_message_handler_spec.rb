require 'rails_helper'

RSpec.describe Custom::ActivityMessageHandler do
  let(:conversation) { create(:conversation) }

  after { Current.executed_by = nil }

  it 'says how long a conversation was pending when the live chat rules resolve it' do
    conversation.update!(status: :pending)
    Current.executed_by = conversation.account.live_chat_rules.create!(auto_solve_hours: 12)

    expect { conversation.update!(status: :resolved) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Conversation was marked resolved by system after 12 hours in pending'))
  end

  it 'uses the singular for one hour' do
    conversation.update!(status: :pending)
    Current.executed_by = conversation.account.live_chat_rules.create!(auto_solve_hours: 1)

    expect { conversation.update!(status: :resolved) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Conversation was marked resolved by system after 1 hour in pending'))
  end

  it 'says how long a conversation was resolved when the live chat rules close it' do
    conversation.update!(status: :resolved)
    Current.executed_by = conversation.account.live_chat_rules.create!

    expect { conversation.update!(status: :closed) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                            content: 'Conversation was closed by system 48 hours after it was resolved',
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
