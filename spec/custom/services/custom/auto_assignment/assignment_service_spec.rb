require 'rails_helper'

RSpec.describe Custom::AutoAssignment::AssignmentService do
  let(:account) { create(:account) }
  let(:project) { Project.create!(account: account, name: 'Share') }
  let(:inbox) { create(:inbox, account: account, project: project, enable_auto_assignment: true) }
  let(:team) { create(:team, account: account) }
  let(:team_agent) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, inbox: inbox, status: 'open') }

  before do
    account.enable_features('assignment_v2')
    account.save!
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: create(:assignment_policy, account: account, enabled: true))
    [team_agent, outsider].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    create(:team_member, team: team, user: team_agent)
    conversation.update!(assignee_id: nil)
  end

  def assign_with_online(*users)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(users.to_h { |user| [user.id.to_s, 'online'] })
    AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment(limit: 5)
    conversation.reload.assignee
  end

  it 'keeps every online inbox member as a candidate when the project has no team' do
    expect(assign_with_online(outsider)).to eq(outsider)
  end

  context 'when an agent holds the chat limit of the project rule' do
    before do
      account.live_chat_rules.create!(project: project, chat_limit: 1)
      create(:conversation, account: account, inbox: create(:inbox, account: account, project: project), assignee: outsider, status: :open)
    end

    it 'skips that agent and assigns another online one' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end

    it 'leaves the conversation unassigned when every online agent is at the limit' do
      expect(assign_with_online(outsider)).to be_nil
    end

    it 'ignores resolved conversations' do
      Conversation.where(assignee: outsider).update_all(status: Conversation.statuses[:resolved]) # rubocop:disable Rails/SkipsModelValidations

      expect(assign_with_online(outsider)).to eq(outsider)
    end
  end

  context 'when an inbox member is a developer' do
    before { account.account_users.find_by(user: outsider).update!(developer: true) }

    it 'leaves the conversation unassigned when only the developer is online' do
      expect(assign_with_online(outsider)).to be_nil
    end

    it 'assigns another online agent instead' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end
  end

  context 'with a balanced policy and a capacity policy', if: ChatwootApp.enterprise? do
    before do
      account.enable_features('advanced_assignment')
      account.save!
      inbox.assignment_policy.update!(assignment_order: :balanced)
      capacity_policy = create(:agent_capacity_policy, account: account)
      create(:inbox_capacity_limit, agent_capacity_policy: capacity_policy, inbox: inbox, conversation_limit: 50)
      [team_agent, outsider].each { |user| account.account_users.find_by(user: user).update!(agent_capacity_policy: capacity_policy) }
      account.account_users.find_by(user: outsider).update!(developer: true)
    end

    it 'leaves the conversation unassigned when only the developer is online' do
      expect(assign_with_online(outsider)).to be_nil
    end

    it 'assigns another online agent instead' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end
  end

  context 'when the project has teams' do
    before { project.teams << team }

    it 'does not assign an online agent outside those teams' do
      expect(assign_with_online(outsider)).to be_nil
    end

    it 'assigns an online member of those teams' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end
  end

  context 'when an agent has just switched to Ready' do
    before do
      account_user = account.account_users.find_by(user: outsider)
      account_user.update!(agent_status: :busy)
      account_user.update!(agent_status: :ready)
    end

    it 'assigns another online agent during the cool-down' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end

    it 'leaves the conversation unassigned while only that agent is online, until the cool-down ends' do
      expect(assign_with_online(outsider)).to be_nil

      travel AgentStatusEvent::READY_COOLDOWN + 1.second

      expect(assign_with_online(outsider)).to eq(outsider)
    end
  end

  context 'when agents are connected with different statuses' do
    before do
      [team_agent, outsider].each { |user| OnlineStatusTracker.update_presence(account.id, 'User', user.id) }
    end

    def assigned_agent
      AutoAssignment::AssignmentService.new(inbox: inbox).perform_bulk_assignment(limit: 5)
      conversation.reload.assignee
    end

    it 'assigns the ready agent and skips the one on lunch' do
      account.account_users.find_by(user: outsider).update!(agent_status: :lunch)

      expect(assigned_agent).to eq(team_agent)
    end

    it 'leaves the conversation unassigned when every connected agent is away' do
      [team_agent, outsider].each { |user| account.account_users.find_by(user: user).update!(agent_status: :busy) }

      expect(assigned_agent).to be_nil
    end
  end
end
