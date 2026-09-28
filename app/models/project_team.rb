# == Schema Information
#
# Table name: project_teams
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#  team_id    :bigint           not null
#
# Indexes
#
#  index_project_teams_on_project_id_and_team_id  (project_id,team_id) UNIQUE
#  index_project_teams_on_team_id                 (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#  fk_rails_...  (team_id => teams.id) ON DELETE => cascade
#
# The teams entitled to a project's chats: when a project has any, only their members
# are offered for assignment and picked by auto-assignment in the project's inboxes.
class ProjectTeam < ApplicationRecord
  belongs_to :project
  belongs_to :team

  validates :team_id, uniqueness: { scope: :project_id }
  validate :team_in_project_account

  private

  def team_in_project_account
    return if team.nil? || project.nil? || team.account_id == project.account_id

    errors.add(:team, I18n.t('errors.projects.team_account_mismatch'))
  end
end
