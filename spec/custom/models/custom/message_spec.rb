require 'rails_helper'

RSpec.describe Custom::Message do
  let(:conversation) { create(:conversation) }

  describe 'an incoming message on a pending conversation' do
    let(:agent) { create(:user, account: conversation.account) }
    let(:message) { build(:message, message_type: :incoming, conversation: conversation) }

    it 'opens a conversation an agent left pending' do
      conversation.update!(status: :pending, assignee: agent)

      message.save!

      expect(conversation.reload).to be_open
    end

    it 'opens it for its agent when the inbox has a bot' do
      conversation.update!(status: :pending, assignee: agent)
      create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: create(:agent_bot, account: conversation.account))

      message.save!

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(agent)
    end

    it 'leaves an unassigned one pending with the bot' do
      conversation.update!(status: :pending, assignee: nil)
      create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: create(:agent_bot, account: conversation.account))

      message.save!

      expect(conversation.reload).to be_pending
    end

    it 'leaves a resolved conversation the bot inbox reopened as pending with the bot' do
      create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: create(:agent_bot, account: conversation.account))
      conversation.resolved!
      create(:message, message_type: :incoming, conversation: conversation)
      expect(conversation.reload).to be_pending

      message.save!

      expect(conversation.reload).to be_pending
    end

    it 'leaves a conversation pending while a bot is assigned to it' do
      conversation.update!(status: :pending, ai_assignee: create(:agent_bot, account: conversation.account))

      message.save!

      expect(conversation.reload).to be_pending
    end

    it 'opens an unassigned pending conversation' do
      conversation.update!(status: :pending, assignee: nil)

      message.save!

      expect(conversation.reload).to be_open
    end

    it 'leaves a muted conversation pending' do
      conversation.mute!
      conversation.update!(status: :pending, assignee: agent)

      message.save!

      expect(conversation.reload).to be_pending
    end
  end

  describe 'a customer writing back to a resolved conversation' do
    let(:inbox) { conversation.inbox }
    let(:agent) { create(:user, account: conversation.account) }
    let(:teammate) { create(:user, account: conversation.account) }

    before do
      create(:inbox_member, inbox: inbox, user: agent)
      create(:inbox_member, inbox: inbox, user: teammate)
      # The round robin reads the inbox's members, which the conversation's inbox cached before these
      inbox.reload
      conversation.update!(assignee: agent)
      conversation.resolved!
    end

    after { Current.reset }

    it 'opens it for its agent in a bot inbox' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: conversation.account))
      agent.account_users.first.update!(auto_offline: false, availability: :online)

      create(:message, message_type: :incoming, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(agent)
    end

    it 'hands it to an online teammate when its agent is offline' do
      teammate.account_users.first.update!(auto_offline: false, availability: :online)

      create(:message, message_type: :incoming, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(teammate)
    end

    it 'names the handover on the timeline' do
      teammate.account_users.first.update!(auto_offline: false, availability: :online)

      expect { create(:message, message_type: :incoming, conversation: conversation) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: "Assigned to #{teammate.name} by Default Policy"))
    end

    it 'hands it only to an online teammate from its team' do
      team = create(:team, account: conversation.account)
      create(:team_member, team: team, user: agent)
      conversation.update!(team: team)
      teammate.account_users.first.update!(auto_offline: false, availability: :online)

      create(:message, message_type: :incoming, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(agent)
    end

    it 'reopens and hands it over once for a burst of customer messages' do
      other_teammate = create(:user, account: conversation.account)
      create(:inbox_member, inbox: inbox, user: other_teammate)
      [teammate, other_teammate].each { |user| user.account_users.first.update!(auto_offline: false, availability: :online) }
      first_copy = Conversation.find(conversation.id)
      second_copy = Conversation.find(conversation.id)
      create(:message, message_type: :incoming, conversation: first_copy)
      handed_to = conversation.reload.assignee_id

      expect { create(:message, message_type: :incoming, conversation: second_copy) }
        .not_to have_enqueued_job(Conversations::ActivityMessageJob)
      expect(conversation.reload.assignee_id).to eq(handed_to)
    end

    it 'reopens a conversation created in this process and brings its copy up to date' do
      teammate.account_users.first.update!(auto_offline: false, availability: :online)
      created_here = create(:conversation, account: conversation.account, inbox: inbox, assignee: agent, status: :resolved)

      create(:message, message_type: :incoming, conversation: created_here)

      expect(created_here).to be_open
      expect(created_here.assignee).to eq(teammate)
    end

    it 'keeps its offline agent when no teammate is online' do
      create(:message, message_type: :incoming, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(agent)
    end

    it 'names the case it reopens on the timeline' do
      kase = Case.find_by!(conversation_id: conversation.id)

      expect { create(:message, message_type: :incoming, conversation: conversation) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: "The customer wrote back · case #{kase.display} reopened, with its history"))
    end
  end

  describe 'an agent replying to a conversation a bot holds' do
    let(:agent) { create(:user, account: conversation.account) }
    let(:agent_bot) { create(:agent_bot, account: conversation.account) }

    before do
      create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: agent_bot)
      conversation.update!(status: :pending, ai_assignee: agent_bot)
    end

    after { Current.reset }

    it 'takes it from the bot' do
      create(:message, message_type: :outgoing, sender: agent, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.ai_assignee).to be_nil
    end

    it 'says on the timeline that the reply opened it' do
      expect { create(:message, message_type: :outgoing, sender: agent, conversation: conversation) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: 'Conversation was marked open automatically after an agent reply'))
    end

    it 'gives it to the agent who replied when nobody holds it, not to the round robin' do
      inbox = conversation.inbox
      inbox.update!(enable_auto_assignment: true)
      teammate = create(:user, account: conversation.account)
      create(:inbox_member, inbox: inbox, user: agent)
      create(:inbox_member, inbox: inbox, user: teammate)
      inbox.reload
      teammate.account_users.first.update!(auto_offline: false, availability: :online)
      Current.user = agent

      create(:message, message_type: :outgoing, sender: agent, conversation: conversation)

      expect(conversation.reload).to be_open
      expect(conversation.assignee).to eq(agent)
    end

    it 'leaves it with the bot for a private note' do
      create(:message, message_type: :outgoing, private: true, sender: agent, conversation: conversation)

      expect(conversation.reload).to be_pending
    end

    it 'leaves it with the bot for a bot reply' do
      create(:message, message_type: :outgoing, sender: agent_bot, conversation: conversation)

      expect(conversation.reload).to be_pending
    end
  end

  describe 'a message on a closed conversation' do
    it 'rejects an outgoing message' do
      conversation.tap(&:resolved!).closed!
      message = build(:message, message_type: :outgoing, conversation: conversation)

      expect(message).not_to be_valid
      expect(message.errors[:base]).to include('Conversation is closed and does not accept new messages')
    end

    it 'reopens it when a customer message reaches it' do
      conversation.tap(&:resolved!).closed!

      create(:message, message_type: :incoming, conversation: conversation)

      expect(conversation.reload).to be_open
    end

    it 'rejects a private note' do
      conversation.tap(&:resolved!).closed!

      expect(build(:message, message_type: :outgoing, private: true, conversation: conversation)).not_to be_valid
    end

    it 'accepts an activity message' do
      conversation.tap(&:resolved!).closed!

      expect(build(:message, message_type: :activity, conversation: conversation)).to be_valid
    end

    it 'still lets an earlier outgoing message take a delivery update' do
      message = create(:message, message_type: :outgoing, conversation: conversation)
      conversation.tap(&:resolved!).closed!

      expect(message.update(status: :delivered)).to be(true)
    end
  end
end
