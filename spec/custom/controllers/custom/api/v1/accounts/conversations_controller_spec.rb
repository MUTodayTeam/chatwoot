require 'rails_helper'

RSpec.describe 'Opening a conversation held by a bot', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :pending, ai_assignee: agent_bot, assignee: nil) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status" }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  it 'gives it to an agent who opens it' do
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
end
