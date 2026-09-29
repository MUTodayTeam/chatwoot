# == Schema Information
#
# Table name: cases
#
#  id               :bigint           not null, primary key
#  reopened_count   :integer          default(0), not null
#  severity         :integer          default("p4"), not null
#  subject          :string           default(""), not null
#  summary          :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  case_category_id :bigint
#  conversation_id  :bigint           not null
#  display_id       :integer          not null
#  project_id       :bigint
#  resolved_by_id   :bigint
#  team_id          :bigint
#
# Indexes
#
#  index_cases_on_account_id_and_created_at  (account_id,created_at)
#  index_cases_on_account_id_and_display_id  (account_id,display_id) UNIQUE
#  index_cases_on_account_id_and_project_id  (account_id,project_id)
#  index_cases_on_account_id_and_team_id     (account_id,team_id)
#  index_cases_on_case_category_id           (case_category_id)
#  index_cases_on_conversation_id            (conversation_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (case_category_id => case_categories.id) ON DELETE => nullify
#
# One case per conversation an agent takes. Its status is the conversation's status and
# its owner is the conversation's assignee, so neither is stored here.
class Case < ApplicationRecord
  SUBJECT_LENGTH = 48
  # Every status a case is still being worked on in (not Solved or Closed)
  OPEN_STATUSES = %w[open pending snoozed].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :project, optional: true
  belongs_to :team, optional: true
  belongs_to :resolved_by, class_name: 'User', optional: true
  # Picked when an agent solves the case; none is "Other"
  belongs_to :case_category, optional: true

  enum :severity, { p1: 0, p2: 1, p3: 2, p4: 3 }, validate: true

  validates :subject, length: { maximum: 255 }, exclusion: { in: [nil], message: :blank }
  validates :summary, length: { maximum: 255 }
  validate :team_belongs_to_account
  validate :case_category_belongs_to_account

  after_create_commit :create_opened_activity
  # The header chip reads the case off the conversation, so an agent's edit has to reach open screens.
  # Solving writes the category and solver on a conversation that is already being broadcast.
  after_update_commit :broadcast_conversation_updated, if: -> { saved_change_to_subject? || saved_change_to_severity? || saved_change_to_team_id? }

  # Opens the case for a conversation the first time an agent takes it, or when it is resolved
  # before anyone did (user is then nil and so is the team). Assignment events can arrive twice
  # or race each other, so the unique conversation_id index decides who wins and the loser
  # returns the winner's case.
  def self.ensure_for!(conversation, user)
    find_by(conversation_id: conversation.id) || open_for!(conversation, user)
  rescue ActiveRecord::RecordNotUnique
    find_by!(conversation_id: conversation.id)
  end

  # display_id runs across the whole account, so the account row serialises the
  # max + 1 read with the insert. The row is locked through a fresh read: a resolve opens
  # cases too, and the conversation's account may carry unsaved changes by then.
  def self.open_for!(conversation, user)
    account = conversation.account
    transaction(requires_new: true) do
      Account.lock.find(account.id)
      create!(
        account: account,
        conversation: conversation,
        project_id: conversation.inbox.project_id,
        team_id: team_id_for(user, conversation),
        display_id: where(account_id: account.id).maximum(:display_id).to_i + 1,
        subject: subject_from(conversation.messages.incoming.reorder(:created_at, :id).first)
      )
    end
  end
  private_class_method :open_for!

  # The opener's first team entitled to the project, else their first team in the account
  def self.team_id_for(user, conversation)
    return if user.nil?

    teams = user.teams.where(account_id: conversation.account_id).order(:id)
    teams.where(id: ProjectTeam.where(project_id: conversation.inbox.project_id).select(:team_id)).pick(:id) || teams.pick(:id)
  end
  private_class_method :team_id_for

  def self.subject_from(message)
    message&.content.to_s.squish.truncate(SUBJECT_LENGTH)
  end

  # #CK-858 when the project has a code, #858 otherwise
  def display
    project&.code.present? ? "##{project.code}-#{display_id}" : "##{display_id}"
  end

  # What a conversation carries about its case
  def push_event_data
    { id: id, display: display, severity: severity, case_category_id: case_category_id, topic: case_category&.c3 }
  end

  private

  # A team_id that loads no team is as wrong as one from another account
  def team_belongs_to_account
    errors.add(:team_id, :invalid) if team_id && team&.account_id != account_id
  end

  def case_category_belongs_to_account
    errors.add(:case_category_id, :invalid) if case_category_id && case_category&.account_id != account_id
  end

  def create_opened_activity
    conversation.messages.create!(
      account_id: account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: opened_activity_content,
      content_attributes: { activity: { type: 'case_opened' } }
    )
    broadcast_conversation_updated
  end

  # The header shows the case, so agents already looking at the conversation need to hear about it.
  # Only their screens: the assignment that opened the case already dispatched conversation_updated,
  # and dispatching it again would run automation rules and webhooks twice.
  def broadcast_conversation_updated
    ActionCableListener.instance.conversation_updated(
      Events::Base.new(Events::Types::CONVERSATION_UPDATED, Time.zone.now, conversation: conversation)
    )
  end

  def opened_activity_content
    return I18n.t('conversations.activity.case_opened', display: display, locale: account.locale) if team.blank?

    I18n.t('conversations.activity.case_opened_for_team', display: display, team: team.name, locale: account.locale)
  end
end
