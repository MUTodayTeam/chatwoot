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

  def assignable_agents(inbox_ids)
    get "/api/v1/accounts/#{account.id}/assignable_agents",
        params: { inbox_ids: inbox_ids },
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    response.parsed_body['payload']
  end

  def assignable_ids(inbox_ids)
    assignable_agents(inbox_ids).pluck('id')
  end

  it 'keeps the stock list, admins included, when the project has no team' do
    expect(assignable_ids([inbox.id])).to contain_exactly(team_agent.id, other_agent.id, admin.id)
  end

  it "counts each agent's active conversations across the project's inboxes against the default limit" do
    sibling_inbox = create(:inbox, account: account, project: project)
    create(:conversation, account: account, inbox: inbox, assignee: team_agent, status: :open)
    create(:conversation, account: account, inbox: sibling_inbox, assignee: team_agent, status: :pending)
    create(:conversation, account: account, inbox: sibling_inbox, assignee: team_agent, status: :snoozed)
    create(:conversation, account: account, inbox: inbox, assignee: team_agent, status: :resolved)
    create(:conversation, account: account, inbox: other_inbox, assignee: team_agent, status: :open)

    loads = assignable_agents([inbox.id]).to_h { |agent| [agent['id'], agent['conversation_load']] }

    expect(loads[team_agent.id]).to eq('assigned_count' => 3, 'limit' => 10)
    expect(loads[admin.id]).to eq('assigned_count' => 0, 'limit' => 10)
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
