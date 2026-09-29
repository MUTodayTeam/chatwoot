# Touch-based productivity (spec 10, 11): every agent that had a turn on a conversation gets
# credit for it, not only the one who solved it. Only conversations whose latest Solved falls in
# the period count, and all of their turns count, including those before a reopen. The Solved
# comes from the conversation_resolved reporting event rather than from a turn, so a
# conversation solved while nobody had it still credits the agents who did.
#
# - resolved: conversations whose latest Solved (or auto-solve) ended the agent's turn, which
#   is then the conversation's last turn
# - assisted: conversations the agent had a turn on but did not resolve
# - transfer_out: the agent's turns that ended in a transfer; general_transfers is the share
#   that costs the transfer penalty
# - transfer_in: the agent's turns that started from someone else's transfer
# - avg_handle_time: seconds per turn
# - avg_first_response: seconds from the customer's first message to the first agent reply, on
#   the conversations where the agent had the first turn
# - score: resolved x 1.0 + assisted x assisted_weight - general_transfers x transfer_penalty,
#   with the weights of the account's default live chat rule
class V2::Reports::AgentProductivityBuilder
  include DateRangeHelper

  RESOLVED_WEIGHT = 1.0
  PERCENT = 100.0

  STATS_SQL = <<~SQL.squish.freeze
    WITH last_solves AS (
      SELECT DISTINCT ON (events.conversation_id) events.conversation_id, events.created_at AS solved_at
      FROM reporting_events events
      INNER JOIN conversations ON conversations.id = events.conversation_id
      WHERE events.account_id = :account_id
        AND events.name = :resolved_event
        AND events.created_at >= :since
        AND conversations.status IN (:finished_statuses)
        AND conversations.inbox_id IN (:inbox_ids)
      ORDER BY events.conversation_id, events.created_at DESC, events.id DESC
    ),
    solved AS (
      SELECT * FROM last_solves WHERE solved_at < :until
    ),
    ordered_turns AS (
      SELECT handlers.*,
             LAG(handlers.end_reason) OVER (PARTITION BY handlers.conversation_id ORDER BY handlers.started_at, handlers.id) AS previous_end_reason,
             ROW_NUMBER() OVER (PARTITION BY handlers.conversation_id ORDER BY handlers.started_at, handlers.id) AS position,
             ROW_NUMBER() OVER (PARTITION BY handlers.conversation_id ORDER BY handlers.started_at DESC, handlers.id DESC) AS position_from_end
      FROM conversation_handlers handlers
      INNER JOIN solved ON solved.conversation_id = handlers.conversation_id
    ),
    resolvers AS (
      SELECT conversation_id, user_id AS resolver_id FROM ordered_turns
      WHERE position_from_end = 1 AND end_reason IN (:solved_reasons)
    ),
    turns AS (
      SELECT ordered_turns.*, resolvers.resolver_id
      FROM ordered_turns
      LEFT JOIN resolvers ON resolvers.conversation_id = ordered_turns.conversation_id
    ),
    first_responses AS (
      SELECT solved.conversation_id, EXTRACT(EPOCH FROM first_reply.replied_at - started.started_at) AS seconds
      FROM solved
      CROSS JOIN LATERAL (
        SELECT MIN(messages.created_at) AS started_at FROM messages
        WHERE messages.conversation_id = solved.conversation_id AND messages.account_id = :account_id
          AND messages.message_type = :incoming
      ) started
      CROSS JOIN LATERAL (
        SELECT MIN(messages.created_at) AS replied_at FROM messages
        WHERE messages.conversation_id = solved.conversation_id AND messages.account_id = :account_id
          AND messages.message_type = :outgoing AND messages.sender_type = 'User' AND messages.private = FALSE
          AND messages.created_at >= started.started_at
      ) first_reply
    )
    SELECT turns.user_id,
           COUNT(DISTINCT turns.conversation_id) FILTER (WHERE turns.user_id = turns.resolver_id) AS resolved,
           COUNT(DISTINCT turns.conversation_id) FILTER (WHERE turns.resolver_id IS DISTINCT FROM turns.user_id) AS assisted,
           COUNT(*) FILTER (WHERE turns.end_reason IN (:transfer_reasons)) AS transfer_out,
           COUNT(*) FILTER (WHERE turns.end_reason = :general_reason) AS general_transfers,
           COUNT(*) FILTER (WHERE turns.previous_end_reason IN (:transfer_reasons)) AS transfer_in,
           AVG(EXTRACT(EPOCH FROM turns.ended_at - turns.started_at)) AS avg_handle_time,
           AVG(first_responses.seconds) FILTER (WHERE turns.position = 1) AS avg_first_response
    FROM turns
    LEFT JOIN first_responses ON first_responses.conversation_id = turns.conversation_id
    GROUP BY turns.user_id
  SQL

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    { weights: weights, agents: agents }
  end

  private

  def agents
    stats = ActiveRecord::Base.connection.select_all(stats_sql).to_a
    names = User.where(id: stats.pluck('user_id')).pluck(:id, :name).to_h

    rows = stats.map { |row| agent_row(row, names[row['user_id']]) }
    rows.sort_by { |row| [-row[:score], row[:name].to_s] }
  end

  def agent_row(row, name)
    resolved, assisted, general_transfers = row.values_at('resolved', 'assisted', 'general_transfers')
    penalty = general_transfers * rule.transfer_penalty

    {
      id: row['user_id'], name: name,
      resolved: resolved, assisted: assisted,
      transfer_out: row['transfer_out'], transfer_in: row['transfer_in'], general_transfers: general_transfers,
      penalty: penalty.to_f.round(2),
      contribution_percent: contribution_percent(resolved, assisted),
      avg_handle_time: row['avg_handle_time']&.to_f&.round,
      avg_first_response: row['avg_first_response']&.to_f&.round,
      score: ((resolved * RESOLVED_WEIGHT) + (assisted * rule.assisted_weight) - penalty).to_f.round(2)
    }
  end

  # The resolved share of the agent's conversations; the rest is assisted. Every listed agent
  # had a turn on a solved conversation, so the total is never zero.
  def contribution_percent(resolved, assisted)
    (resolved * PERCENT / (resolved + assisted)).round(1)
  end

  def weights
    { resolved: RESOLVED_WEIGHT, assisted: rule.assisted_weight.to_f, transfer_penalty: rule.transfer_penalty.to_f }
  end

  def rule
    @rule ||= LiveChatRule.for_project(account, nil)
  end

  def stats_sql
    ActiveRecord::Base.sanitize_sql_array(
      [STATS_SQL, {
        account_id: account.id, since: range.begin, until: range.end, inbox_ids: inbox_ids, resolved_event: 'conversation_resolved',
        solved_reasons: end_reason_values(ConversationHandler::SOLVED_REASONS),
        transfer_reasons: end_reason_values(ConversationHandler::TRANSFER_REASONS),
        general_reason: ConversationHandler.end_reasons[:general],
        finished_statuses: ConversationHandler::FINISHED_STATUSES.map { |status| Conversation.statuses[status] },
        incoming: Message.message_types[:incoming], outgoing: Message.message_types[:outgoing]
      }]
    )
  end

  def end_reason_values(reasons)
    reasons.map { |reason| ConversationHandler.end_reasons[reason] }
  end

  def inbox_ids
    inboxes = params[:project_id].present? ? account.projects.find(params[:project_id]).inboxes : account.inboxes
    inboxes.pluck(:id)
  end
end
