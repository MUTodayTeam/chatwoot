# == Schema Information
#
# Table name: live_chat_rules
#
#  id                    :bigint           not null, primary key
#  assisted_weight       :decimal(4, 2)    default(0.5), not null
#  auto_close_hours      :integer          default(48), not null
#  chat_limit            :integer          default(10), not null
#  auto_solve_hours      :integer          default(24), not null
#  extension_minutes     :integer          default(60), not null
#  reply_timeout_minutes :integer          default(60), not null
#  transfer_penalty      :decimal(4, 2)    default(0.2), not null
#  waiting_time_minutes  :integer          default(60), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  project_id            :bigint
#  transfer_team_id      :bigint
#
# Indexes
#
#  index_live_chat_rules_on_account_id                 (account_id)
#  index_live_chat_rules_on_account_id_and_project_id  (account_id,project_id) UNIQUE
#  index_live_chat_rules_on_account_id_default         (account_id) UNIQUE WHERE (project_id IS NULL)
#  index_live_chat_rules_on_project_id                 (project_id)
#  index_live_chat_rules_on_transfer_team_id           (transfer_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (transfer_team_id => teams.id) ON DELETE => nullify
#
class LiveChatRule < ApplicationRecord
  belongs_to :account
  belongs_to :project, optional: true
  belongs_to :transfer_team, class_name: 'Team', optional: true

  # A year at most. Much larger values put `n.hours.ago` outside the timestamp range, and
  # the query that raises would stop the sweep for every account after this one.
  MAX_MINUTES = 525_600
  MAX_HOURS = 8_760

  validates :reply_timeout_minutes, :extension_minutes, :waiting_time_minutes,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }
  validates :auto_solve_hours, :auto_close_hours, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_HOURS }
  MAX_CHAT_LIMIT = 1_000

  validates :chat_limit, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_CHAT_LIMIT }
  validates :assisted_weight, :transfer_penalty, numericality: { greater_than_or_equal_to: 0, less_than: 100 }
  validates :project_id, uniqueness: { scope: :account_id }
  validate :transfer_team_in_account

  # The rule that governs a project: its own row if it has one, otherwise the
  # account-wide default row (project_id nil). An account that has configured
  # neither gets an unsaved row carrying the column defaults.
  def self.for_project(account, project)
    rules = account.live_chat_rules
    (project && rules.find_by(project_id: project.id)) || rules.find_by(project_id: nil) || new(account: account)
  end

  # The team a project's conversations are transferred to (spec 7.2). Unlike the other
  # settings it falls back to the account default when the project's own rule leaves it unset,
  # so a project override does not have to repeat it.
  def self.transfer_team_for(account, project)
    rules = account.live_chat_rules.where(project_id: [project&.id, nil].uniq).where.not(transfer_team_id: nil).includes(:transfer_team)
    rules.max_by { |rule| rule.project_id ? 1 : 0 }&.transfer_team
  end

  private

  def transfer_team_in_account
    errors.add(:transfer_team_id, :invalid) if transfer_team_id? && transfer_team&.account_id != account_id
  end
end
