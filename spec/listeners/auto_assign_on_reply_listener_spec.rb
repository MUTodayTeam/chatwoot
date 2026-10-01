require 'rails_helper'

describe AutoAssignOnReplyListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, account: account, conversation: conversation, message_type: :outgoing, sender: agent) }
  let(:event) { Events::Base.new('message_created', Time.zone.now, message: message) }

  before { create(:inbox_member, user: agent, inbox: conversation.inbox) }

  describe '#message_created' do
    it 'assigns an unassigned conversation to the agent who replies' do
      expect { listener.message_created(event) }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
                              content: "#{agent.name} self-assigned this conversation",
                              content_attributes: { activity: { type: 'assignee_changed' } } })
      expect(conversation.reload.assignee).to eq(agent)
      expect(Current.user).to be_nil
    end

    it 'takes over a conversation that only has a bot assignee' do
      conversation.update!(ai_assignee: create(:agent_bot, account: account), status: :pending)

      listener.message_created(event)

      expect(conversation.reload).to have_attributes(assignee: agent, ai_assignee: nil, status: 'open')
    end

    it 'does not assign on a private note' do
      message.update!(private: true)

      listener.message_created(event)

      expect(conversation.reload.assignee).to be_nil
    end

    context 'when the conversation already has an assignee' do
      let(:assignee) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, assignee: assignee) }

      it 'does not reassign it' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to eq(assignee)
      end
    end

    context 'when the sender is a developer' do
      before { agent.account_users.first.update!(developer: true) }

      it 'does not assign' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'when the sender has no access to the inbox' do
      let(:message) do
        create(:message, account: account, conversation: conversation, message_type: :outgoing,
                         sender: create(:user, account: account, role: :agent))
      end

      it 'does not assign' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'when the message is incoming' do
      let(:message) { create(:message, account: account, conversation: conversation, message_type: :incoming) }

      it 'does not assign' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'when the sender is not a user' do
      let(:message) do
        create(:message, account: account, conversation: conversation, message_type: :outgoing,
                         sender: create(:agent_bot, account: account))
      end

      it 'does not assign' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'when the message was sent by an automation rule' do
      let(:message) do
        create(:message, account: account, conversation: conversation, message_type: :outgoing, sender: agent,
                         content_attributes: { automation_rule_id: 1 })
      end

      it 'does not assign' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'when the inbox belongs to a project with teams' do
      let(:project) { Project.create!(account: account, name: 'Share') }
      let(:team) { create(:team, account: account) }

      before do
        conversation.inbox.update!(project: project)
        project.teams << team
      end

      it 'does not assign an inbox member outside those teams' do
        listener.message_created(event)
        expect(conversation.reload.assignee).to be_nil
      end

      it 'assigns a member of those teams' do
        create(:team_member, team: team, user: agent)

        listener.message_created(event)
        expect(conversation.reload.assignee).to eq(agent)
      end
    end
  end
end
