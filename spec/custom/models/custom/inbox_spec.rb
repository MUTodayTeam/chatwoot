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
      expect(inbox.entitled_assignable_agents).to contain_exactly(team_agent, other_agent, team_admin, other_admin)
    end

    it 'keeps every inbox member as an auto-assignment candidate' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, other_agent.id, team_admin.id)
    end
  end

  context 'when an agent holds the chat limit of the project rule' do
    before do
      account.live_chat_rules.create!(project: project, chat_limit: 2)
      # The second conversation sits in another inbox of the project: the load counts the whole project.
      create(:conversation, account: account, inbox: inbox, assignee: other_agent, status: :open)
      create(:conversation, account: account, inbox: create(:inbox, account: account, project: project), assignee: other_agent, status: :pending)
      create(:conversation, account: account, inbox: inbox, assignee: team_agent, status: :open)
    end

    it 'drops that agent from the auto-assignment candidates' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, team_admin.id)
    end

    it 'falls back to the account default rule when the project has none' do
      account.live_chat_rules.find_by(project: project).destroy!
      account.live_chat_rules.create!(project_id: nil, chat_limit: 1)

      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_admin.id)
    end
  end

  context 'when an inbox member is a developer' do
    before { account.account_users.find_by(user: other_agent).update!(developer: true) }

    it 'drops the developer from the auto-assignment candidates' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, team_admin.id)
    end

    it 'still offers the developer for a manual assignment' do
      expect(inbox.entitled_assignable_agents).to include(other_agent)
      expect(inbox.assignable_agents).to include(other_agent)
    end
  end

  context 'when the project has teams' do
    before { project.teams << team }

    it 'offers only inbox members of those teams, admins included only through a team' do
      expect(inbox.entitled_assignable_agents).to contain_exactly(team_agent, team_admin)
    end

    it 'leaves out a team member who is not in the inbox' do
      create(:team_member, team: team, user: create(:user, account: account, role: :agent))

      expect(inbox.entitled_assignable_agents).to contain_exactly(team_agent, team_admin)
    end

    it 'keeps the stock assignable agents, which also decide who can be a participant' do
      expect(inbox.assignable_agents).to contain_exactly(team_agent, other_agent, team_admin, other_admin)
    end

    it 'still lets an inbox member or an admin outside those teams be a participant' do
      conversation = create(:conversation, account: account, inbox: inbox)

      expect(conversation.conversation_participants.create(user: other_agent)).to be_persisted
      expect(conversation.conversation_participants.create(user: other_admin)).to be_persisted
    end

    it 'narrows auto-assignment candidates to those teams' do
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(team_agent.id, team_admin.id)
    end
  end

  it 'keeps an inbox without a project on stock behaviour' do
    inbox.update!(project: nil)

    expect(inbox.entitled_assignable_agents).to contain_exactly(team_agent, other_agent, team_admin, other_admin)
  end
end
