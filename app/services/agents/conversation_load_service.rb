# How many open, pending and snoozed conversations each agent holds in the given inboxes, against
# the limit they are measured on: the project's live chat rule (10 unless configured, CDP spec §15), or the advanced assignment caps in Enterprise.
# The CDP dashboard's agent load, the Assign dialog and the Agents settings list all read it.
class Agents::ConversationLoadService
  ACTIVE_CONVERSATION_STATUSES = %w[open pending snoozed].freeze

  attr_reader :account, :inbox_ids, :user_ids, :project

  # project picks the live chat rule that sets the limit; without one the account default applies.
  def initialize(account:, inbox_ids:, user_ids:, project: nil)
    @account = account
    @inbox_ids = inbox_ids
    @user_ids = user_ids
    @project = project
  end

  # { user_id => { assigned_count: n, limit: n } }
  def perform
    inbox_limits = agent_inbox_limits

    user_ids.index_with do |user_id|
      limits = inbox_limits[user_id]
      # An agent with per-inbox caps is measured only on the capped inboxes, against the sum of those caps.
      next { assigned_count: assigned_count(user_id, inbox_ids), limit: chat_limit } unless limits

      { assigned_count: assigned_count(user_id, limits.keys), limit: limits.values.sum }
    end
  end

  private

  def chat_limit
    @chat_limit ||= LiveChatRule.for_project(account, project).chat_limit
  end

  def assigned_count(user_id, counted_inbox_ids)
    active_counts.sum { |(assignee_id, inbox_id), count| assignee_id == user_id && counted_inbox_ids.include?(inbox_id) ? count : 0 }
  end

  def active_counts
    @active_counts ||= account.conversations.where(inbox_id: inbox_ids, assignee_id: user_ids, status: ACTIVE_CONVERSATION_STATUSES)
                              .group(:assignee_id, :inbox_id).count
  end

  # { user_id => { inbox_id => limit } } for agents capped per inbox; Enterprise reads advanced assignment capacity policies.
  def agent_inbox_limits
    {}
  end
end

Agents::ConversationLoadService.prepend_mod_with('Agents::ConversationLoadService')
