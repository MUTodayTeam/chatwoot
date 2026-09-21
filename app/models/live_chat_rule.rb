# == Schema Information
#
# Table name: live_chat_rules
#
#  id                    :bigint           not null, primary key
#  extension_minutes     :integer          default(60), not null
#  reply_timeout_minutes :integer          default(60), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  project_id            :bigint
#
# Indexes
#
#  index_live_chat_rules_on_account_id                 (account_id)
#  index_live_chat_rules_on_account_id_and_project_id  (account_id,project_id) UNIQUE
#  index_live_chat_rules_on_project_id                 (project_id)
#
class LiveChatRule < ApplicationRecord
  belongs_to :account
  belongs_to :project, optional: true

  validates :reply_timeout_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :extension_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :project_id, uniqueness: { scope: :account_id }

  # The rule that governs a project: its own row if it has one, otherwise the
  # account-wide default row (project_id nil). An account that has configured
  # neither gets an unsaved row carrying the column defaults.
  def self.for_project(account, project)
    rules = account.live_chat_rules
    (project && rules.find_by(project_id: project.id)) || rules.find_by(project_id: nil) || new(account: account)
  end
end
