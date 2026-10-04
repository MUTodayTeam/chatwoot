require 'rails_helper'

RSpec.describe 'Changing the status of a conversation', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending, ai_assignee: agent_bot, assignee: nil) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status" }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
  end

  it 'gives a conversation held by a bot to an agent who opens it' do
    post path, params: { status: 'open' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to have_attributes(status: 'open', ai_assignee: nil, assignee: agent)
  end

  it 'takes it from the bot but does not assign it to a developer who opens it' do
    agent.account_users.first.update!(developer: true)

    post path, params: { status: 'open' }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to have_attributes(status: 'open', ai_assignee: nil, assignee: nil)
  end

  context 'when nobody holds the conversation' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open, assignee: nil) }

    it 'gives it to the agent who resolves it, whose turn ends as Solved' do
      post path, params: { status: 'resolved' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to have_attributes(status: 'resolved', assignee: agent)
      expect(ConversationHandler.where(conversation: conversation).pluck(:user_id, :end_reason)).to eq([[agent.id, 'solved']])
    end

    it 'gives it to an administrator who puts it on hold' do
      administrator = create(:user, account: account, role: :administrator)

      post path, params: { status: 'snoozed' }, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to have_attributes(status: 'snoozed', assignee: administrator)
    end
  end

  context 'when another agent holds the conversation' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending, assignee: other_agent) }

    it 'leaves it with them when an agent opens it' do
      post path, params: { status: 'open' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to have_attributes(status: 'open', assignee: other_agent)
    end

    it 'leaves it with them when an agent resolves it' do
      post path, params: { status: 'resolved' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to have_attributes(status: 'resolved', assignee: other_agent)
    end
  end
end
