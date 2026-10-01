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

  describe 'marking an agent as a developer' do
    let(:path) { "/api/v1/accounts/#{account.id}/agents/#{agent.id}" }

    it 'lets an administrator mark and unmark an agent' do
      put path, params: { developer: true }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['developer']).to be(true)
      expect(agent.account_users.first.reload).to be_developer

      put path, params: { developer: false }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['developer']).to be(false)
      expect(agent.account_users.first.reload).not_to be_developer
    end

    it 'refuses an agent' do
      put path, params: { developer: true }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(agent.account_users.first.reload).not_to be_developer
    end

    it 'carries the mark in the agents list and in the profile' do
      agent.account_users.first.update!(developer: true)

      get "/api/v1/accounts/#{account.id}/agents", headers: admin.create_new_auth_token, as: :json
      marks = response.parsed_body.to_h { |user| [user['id'], user['developer']] }
      get '/api/v1/profile', headers: agent.create_new_auth_token, as: :json

      expect(marks).to eq(agent.id => true, admin.id => false)
      expect(response.parsed_body['accounts'].first['developer']).to be(true)
    end
  end
end
