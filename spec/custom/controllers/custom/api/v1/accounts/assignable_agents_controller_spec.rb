require 'rails_helper'

RSpec.describe 'Assignable agents of a project with teams', type: :request do
  let(:account) { create(:account) }
  let(:project) { Project.create!(account: account, name: 'Share') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:team_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let!(:admin) { create(:user, account: account, role: :administrator) }

  before do
    [team_agent, other_agent].each do |user|
      create(:inbox_member, inbox: inbox, user: user)
      create(:inbox_member, inbox: other_inbox, user: user)
    end
    create(:team_member, team: team, user: team_agent)
  end

  def assignable_ids(inbox_ids)
    get "/api/v1/accounts/#{account.id}/assignable_agents",
        params: { inbox_ids: inbox_ids },
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    response.parsed_body['payload'].pluck('id')
  end

  it 'keeps the stock list, admins included, when the project has no team' do
    expect(assignable_ids([inbox.id])).to contain_exactly(team_agent.id, other_agent.id, admin.id)
  end

  context 'when the project has teams' do
    before { project.teams << team }

    it 'lists only the inbox members of those teams and leaves admins out' do
      expect(assignable_ids([inbox.id])).to contain_exactly(team_agent.id)
    end

    it 'keeps an admin who is in one of those teams' do
      create(:inbox_member, inbox: inbox, user: admin)
      create(:team_member, team: team, user: admin)

      expect(assignable_ids([inbox.id])).to contain_exactly(team_agent.id, admin.id)
    end

    it 'intersects with the stock list of an inbox outside any project' do
      expect(assignable_ids([inbox.id, other_inbox.id])).to contain_exactly(team_agent.id)
    end
  end
end
