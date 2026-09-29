# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  code        :string(10)
#  color       :string
#  description :string
#  name        :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_projects_on_account_id           (account_id)
#  index_projects_on_account_id_and_name  (account_id,name) UNIQUE
#
class Project < ApplicationRecord
  include Avatarable

  belongs_to :account
  has_many :inboxes, dependent: :nullify
  has_many :live_chat_rules, dependent: :destroy
  has_many :project_teams, dependent: :delete_all
  has_many :teams, through: :project_teams
  has_many :cases, dependent: :nullify

  # The case number prefix, as in CK-858
  normalizes :code, with: ->(code) { code.strip.upcase.presence }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :code, length: { maximum: 10 }, format: { with: /\A[A-Z0-9]+\z/ }, allow_nil: true

  # Members of the teams entitled to this project's chats, or nil when no team is set,
  # in which case every inbox member stays entitled as in stock Chatwoot.
  def entitled_user_ids
    team_ids = project_teams.pluck(:team_id)
    TeamMember.where(team_id: team_ids).distinct.pluck(:user_id) if team_ids.any?
  end
end
