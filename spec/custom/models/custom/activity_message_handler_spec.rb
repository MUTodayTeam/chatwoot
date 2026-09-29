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
                            content_attributes: { activity: { type: 'conversation_status_changed', status: 'closed', automated: true } } })
  end

  it 'leaves a status change by an agent unmarked' do
    Current.user = create(:user, account: conversation.account)

    expect { conversation.update!(status: :resolved) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content_attributes: { activity: { type: 'conversation_status_changed', status: 'resolved' } }))
  ensure
    Current.user = nil
  end

  describe 'activity types for the conversation timeline' do
    let(:agent) { create(:user, account: conversation.account) }

    it 'tags an assignment' do
      Current.user = agent

      expect { conversation.update!(assignee: agent) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content_attributes: { activity: { type: 'assignee_changed' } }))
    ensure
      Current.user = nil
    end

    it 'tags a team assignment that assigns an agent in the same save' do
      Current.user = agent
      team = create(:team, account: conversation.account)
      create(:team_member, team: team, user: agent)

      expect { conversation.update!(team: team, assignee: agent) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: "Assigned to #{agent.name} via #{team.name} by #{agent.name}",
                                           content_attributes: { activity: { type: 'team_changed' } }))
    ensure
      Current.user = nil
    end

    it 'tags a reply deadline extension' do
      Current.user = agent

      expect { conversation.send(:create_reply_deadline_extended_message, 60) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content_attributes: { activity: { type: 'reply_deadline_extended' } }))
    ensure
      Current.user = nil
    end

    it 'leaves other activities without a type' do
      Current.user = agent

      expect { conversation.send(:create_muted_message) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_excluding(:content_attributes))
    ensure
      Current.user = nil
    end
  end

  it 'keeps the automation rule copy' do
    conversation.update!(status: :resolved)
    Current.executed_by = create(:automation_rule, account: conversation.account)

    expect { conversation.update!(status: :closed) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Conversation was closed by Automation System'))
  end
end
