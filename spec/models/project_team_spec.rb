require 'rails_helper'

RSpec.describe ProjectTeam do
  let(:account) { create(:account) }
  let(:project) { Project.create!(account: account, name: 'Share') }

  it 'links a team of the same account once' do
    team = create(:team, account: account)
    described_class.create!(project: project, team: team)

    expect(described_class.new(project: project, team: team)).not_to be_valid
  end

  it 'rejects a team of another account' do
    project_team = described_class.new(project: project, team: create(:team))

    expect(project_team).not_to be_valid
    expect(project_team.errors[:team]).to be_present
  end

  it 'goes away with its team' do
    team = create(:team, account: account)
    described_class.create!(project: project, team: team)
    team.destroy!

    expect(project.teams.reload).to be_empty
  end
end
