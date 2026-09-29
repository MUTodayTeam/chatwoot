require 'rails_helper'

RSpec.describe 'Canned responses scoped to a project', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { account.projects.create!(name: 'Checkin+') }
  let(:other_project) { account.projects.create!(name: 'Share') }
  let!(:global_response) { create(:canned_response, account: account, short_code: 'thanks') }
  let!(:project_response) { create(:canned_response, account: account, project: project, short_code: 'checkin-thanks') }
  let!(:other_response) { create(:canned_response, account: account, project: other_project, short_code: 'share-thanks') }

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    it 'lists every response without a project_id' do
      get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to contain_exactly(global_response.id, project_response.id, other_response.id)
    end

    it "lists the project's responses and the shared ones with a project_id" do
      get "/api/v1/accounts/#{account.id}/canned_responses", params: { project_id: project.id }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to contain_exactly(global_response.id, project_response.id)
      expect(response.parsed_body.find { |record| record['id'] == project_response.id }['project_id']).to eq(project.id)
    end

    it 'combines with the search' do
      get "/api/v1/accounts/#{account.id}/canned_responses",
          params: { project_id: project.id, search: 'checkin' }, headers: agent.create_new_auth_token

      expect(response.parsed_body.pluck('id')).to eq([project_response.id])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    it 'creates a response for a project' do
      post "/api/v1/accounts/#{account.id}/canned_responses",
           params: { short_code: 'welcome', content: 'Welcome', project_id: project.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['project_id']).to eq(project.id)
      expect(account.canned_responses.find_by(short_code: 'welcome').project).to eq(project)
    end

    it "rejects another account's project" do
      foreign_project = create(:account).projects.create!(name: 'Foreign')

      post "/api/v1/accounts/#{account.id}/canned_responses",
           params: { short_code: 'welcome', content: 'Welcome', project_id: foreign_project.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.canned_responses.find_by(short_code: 'welcome')).to be_nil
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/canned_responses/:id' do
    it 'moves a response to a project' do
      patch "/api/v1/accounts/#{account.id}/canned_responses/#{global_response.id}",
            params: { project_id: other_project.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['project_id']).to eq(other_project.id)
      expect(global_response.reload.project).to eq(other_project)
    end

    it 'shares a response with every project again' do
      patch "/api/v1/accounts/#{account.id}/canned_responses/#{project_response.id}",
            params: { project_id: nil }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(project_response.reload.project_id).to be_nil
    end
  end
end
