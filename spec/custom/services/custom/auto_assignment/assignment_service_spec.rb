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

  context 'when the project has teams' do
    before { project.teams << team }

    it 'does not assign an online agent outside those teams' do
      expect(assign_with_online(outsider)).to be_nil
    end

    it 'assigns an online member of those teams' do
      expect(assign_with_online(outsider, team_agent)).to eq(team_agent)
    end
  end
end
