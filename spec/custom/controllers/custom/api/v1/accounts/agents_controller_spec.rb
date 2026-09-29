require 'rails_helper'

RSpec.describe 'Agents list with conversation load', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, project: Project.create!(account: account, name: 'Share')) }
  let(:other_inbox) { create(:inbox, account: account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)
    create(:conversation, account: account, inbox: other_inbox, assignee: agent, status: :snoozed)
    create(:conversation, account: account, inbox: other_inbox, assignee: agent, status: :resolved)
    create(:conversation, account: create(:account), assignee: agent, status: :open)
  end

  it "shows an admin each agent's active conversations across every inbox of the account" do
    get "/api/v1/accounts/#{account.id}/agents", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    loads = response.parsed_body.to_h { |user| [user['id'], user['conversation_load']] }
    expect(loads).to eq(agent.id => { 'assigned_count' => 2, 'limit' => 10 }, admin.id => { 'assigned_count' => 0, 'limit' => 10 })
  end

  it 'leaves the load out for an agent, who cannot see the reports' do
    get "/api/v1/accounts/#{account.id}/agents", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to all(satisfy { |user| !user.key?('conversation_load') })
  end
end
