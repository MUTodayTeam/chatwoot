require 'rails_helper'

RSpec.describe 'Agent status API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { Project.create!(account: account, name: 'Share') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:url) { "/api/v1/accounts/#{account.id}/agent_status" }

  describe 'GET /api/v1/accounts/{account.id}/agent_status' do
    it 'returns 401 for an unauthenticated request' do
      get url

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns the status, the since time and today per status' do
      get url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body).to include('agent_status' => 'ready', 'availability' => 'online')
      expect(body['since']).to be_present
      expect(body['today'].keys).to contain_exactly('ready', 'busy', 'mini_break', 'lunch', 'briefing', 'rest_room', 'online_total')
      expect(body['server_time']).to be_present
    end

    it "returns the load against the project's chat limit" do
      account.live_chat_rules.create!(project: project, chat_limit: 4)
      create(:conversation, account: account, inbox: inbox, assignee: agent, status: :open)

      get url, params: { project_id: project.id }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['load']).to eq('active' => 1, 'limit' => 4)
    end

    it 'falls back to the account default chat limit without a project' do
      account.live_chat_rules.create!(project_id: nil, chat_limit: 6)

      get url, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['load']).to eq('active' => 0, 'limit' => 6)
    end

    it 'returns 404 for a project of another account' do
      other_project = Project.create!(account: create(:account), name: 'Other')

      get url, params: { project_id: other_project.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'does not let an agent read another account' do
      get "/api/v1/accounts/#{create(:account).id}/agent_status", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/agent_status' do
    it 'sets the status and answers with it' do
      put url, params: { agent_status: 'lunch' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('agent_status' => 'lunch', 'availability' => 'busy')
      expect(account.account_users.find_by(user: agent)).to be_agent_status_lunch
    end

    it 'returns 422 for an unknown status' do
      put url, params: { agent_status: 'nap' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.account_users.find_by(user: agent)).to be_agent_status_ready
    end

    it 'only changes the status in the account of the request' do
      other_account = create(:account)
      create(:account_user, account: other_account, user: agent)

      put url, params: { agent_status: 'lunch' }, headers: agent.create_new_auth_token, as: :json

      expect(other_account.account_users.find_by(user: agent)).to be_agent_status_ready
    end
  end
end
