require 'rails_helper'

RSpec.describe Custom::Inbox do
  let(:account) { create(:account) }
  let(:project) { Project.create!(account: account, name: 'Share') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:team) { create(:team, account: account) }
  let(:team_agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:team_admin) { create(:user, account: account, role: :administrator) }
  let!(:other_admin) { create(:user, account: account, role: :administrator) }

  before do
    [team_agent, other_agent, team_admin].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    create(:team_member, team: team, user: team_agent)
    create(:team_member, team: team, user: team_admin)
  end

  context 'when the project has no team' do
    it 'keeps every inbox member and every admin assignable' do
      expect(inbox.assignable_agents).to contain_exactly(team_agent, other_agent, team_admin, other_admin)
    end

    it 'keeps every inbox member as an auto-assignment candidate' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, other_agent.id, team_admin.id)
    end
  end

  context 'when the project has teams' do
    before { project.teams << team }

    it 'offers only inbox members of those teams, admins included only through a team' do
      expect(inbox.assignable_agents).to contain_exactly(team_agent, team_admin)
    end

    it 'leaves out a team member who is not in the inbox' do
      create(:team_member, team: team, user: create(:user, account: account, role: :agent))

      expect(inbox.assignable_agents).to contain_exactly(team_agent, team_admin)
    end

    it 'narrows auto-assignment candidates to those teams' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, team_admin.id)
    end
  end

  it 'keeps an inbox without a project on stock behaviour' do
    inbox.update!(project: nil)

    expect(inbox.assignable_agents).to contain_exactly(team_agent, other_agent, team_admin, other_admin)
  end
end
