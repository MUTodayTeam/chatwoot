# One agent's turn looking after a conversation (spec 2.2 handlers). A turn starts when the
# agent takes the conversation and ends when it moves on: to another agent (assign, or a
# transfer with its reason), to nobody, or to Solved. Productivity credits every agent that
# had a turn, not only the one who solved it.
class ConversationHandler < ApplicationRecord
  TRANSFER_REASONS = %w[scope escalate shift general].freeze
  SOLVED_REASONS = %w[solved auto_solved].freeze
  # A Solved or Closed conversation has no open turn; reopening it starts one
  FINISHED_STATUSES = %w[resolved closed].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :user
  belongs_to :ended_by, class_name: 'User', optional: true

  # Prefixed: a bare `scope` value would collide with ActiveRecord's scope
  enum :end_reason, { assign: 0, scope: 1, escalate: 2, shift: 3, general: 4, solved: 5, auto_solved: 6, unassigned: 7 }, prefix: true

  scope :open, -> { where(ended_at: nil) }

  # A single UPDATE on the open row, so a second close of the same turn (a synchronous close
  # followed by the event for the same change, or two events at once) finds nothing and
  # returns 0.
  def self.close_open!(conversation, reason:, ended_by: nil, note: nil, at: Time.current)
    # rubocop:disable Rails/SkipsModelValidations
    open.where(conversation_id: conversation.id)
        .update_all(ended_at: at, end_reason: end_reasons.fetch(reason.to_s), ended_by_id: ended_by&.id, note: note.presence, updated_at: at)
    # rubocop:enable Rails/SkipsModelValidations
  end

  # The partial unique index allows one open turn per conversation, so of two events opening
  # the same turn one inserts and the other returns nil. The savepoint keeps a caller's
  # transaction usable after the losing insert.
  def self.open_for!(conversation, user, at: Time.current)
    transaction(requires_new: true) do
      create!(account_id: conversation.account_id, conversation: conversation, user: user, started_at: at)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
