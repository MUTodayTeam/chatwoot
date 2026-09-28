require 'rails_helper'

RSpec.describe 'Projects API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }

  describe 'POST /api/v1/accounts/{account.id}/projects' do
    it 'links the chosen teams and returns their ids' do
      post "/api/v1/accounts/#{account.id}/projects",
           params: { name: 'Share', team_ids: [team.id, other_team.id] },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['team_ids']).to contain_exactly(team.id, other_team.id)
      expect(Project.last.teams).to contain_exactly(team, other_team)
    end

    it 'ignores a team of another account' do
      post "/api/v1/accounts/#{account.id}/projects",
           params: { name: 'Share', team_ids: [create(:team).id] },
           headers: admin.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['team_ids']).to be_empty
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/projects/:id' do
    let(:project) { Project.create!(account: account, name: 'Share', teams: [team]) }

    it 'replaces the teams' do
      patch "/api/v1/accounts/#{account.id}/projects/#{project.id}",
            params: { team_ids: [other_team.id] },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(project.reload.teams).to contain_exactly(other_team)
    end

    it 'clears the teams from a multipart blank entry' do
      patch "/api/v1/accounts/#{account.id}/projects/#{project.id}",
            params: { project: { team_ids: [''] } },
            headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(project.reload.teams).to be_empty
    end

    it 'leaves the teams alone when team_ids is not sent' do
      patch "/api/v1/accounts/#{account.id}/projects/#{project.id}",
            params: { name: 'Renamed' },
            headers: admin.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:success)
      expect(project.reload.teams).to contain_exactly(team)
    end
  end
end
