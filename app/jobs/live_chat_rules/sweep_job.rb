# Moves conversations along the live chat lifecycle as time passes, following the
# live chat rule that governs each inbox's project:
#
# - missed: open, nobody assigned and nobody replied within waiting_time_minutes of
#   becoming open (a conversation the bot held counts from its handoff)
# - expired: open and past its reply deadline (the Lark overdue alert's condition)
# - pending for auto_solve_hours -> resolved, unless the conversation is with a bot
# - resolved for auto_close_hours -> closed
#
# Nothing fires an event when a clock runs out, so config/schedule.yml runs this every
# minute. Each step only matches rows that still need it, so a run that overlaps the
# previous one, or repeats it, changes nothing twice.
#
# Accounts that use these rules must leave the account setting auto_resolve_after
# unset: Conversations::ResolutionJob would resolve open conversations on its own clock.
class LiveChatRules::SweepJob < ApplicationJob
  queue_as :scheduled_jobs

  # status_changed_at arrived with v4.18.0 and was never backfilled, on purpose: stock
  # delayed automations treat a missing value as "no status clock" (see
  # AutomationRulePendingExecution.schedule). Older rows count from their last update.
  STATUS_CLOCK = 'COALESCE(conversations.status_changed_at, conversations.updated_at)'.freeze

  def perform
    Account.active.find_each do |account|
      inboxes_by_rule(account).each { |rule, inboxes| sweep(account.conversations.where(inbox: inboxes), inboxes, rule) }
    end
  end

  private

  # Every inbox follows its project's rule, else the account default, as in
  # LiveChatRule.for_project. The default row is saved here because the dispatcher
  # serialises Current.executed_by as a GlobalID, which an unsaved rule does not have.
  def inboxes_by_rule(account)
    default_rule = default_rule_for(account)
    project_rules = account.live_chat_rules.where.not(project_id: nil).index_by(&:project_id)
    account.inboxes.group_by { |inbox| project_rules[inbox.project_id] || default_rule }
  end

  # Two overlapping runs can both miss the row; the unique index lets only one insert it.
  def default_rule_for(account)
    account.live_chat_rules.find_or_create_by!(project_id: nil)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def sweep(conversations, inboxes, rule)
    # The activity messages name the rule, so they read as automatic.
    Current.executed_by = rule
    flag_expired(conversations)
    flag_missed(conversations, rule)
    # The assignee's turn ends as auto-solved, so they get the Resolved credit (spec 10)
    transition(auto_solvable(conversations, inboxes, rule), :resolved) do |conversation|
      ConversationHandler.close_open!(conversation, reason: :auto_solved)
    end
    transition(conversations.resolved.where("#{STATUS_CLOCK} < ?", rule.auto_close_hours.hours.ago), :closed)
  ensure
    Current.executed_by = nil
  end

  # The flags are markers for reporting. Saving each row (see transition) rather than
  # updating them in bulk lets conversation_updated reach open tabs and writes the
  # timeline activity, and only unflagged rows match, so each is flagged once.
  def flag_expired(conversations)
    transition(conversations.open.where.not(waiting_since: nil).where(reply_due_at: ...Time.current, expired_at: nil),
               expired_at: Time.current)
  end

  def flag_missed(conversations, rule)
    transition(conversations.open.where(assignee_id: nil, first_reply_created_at: nil, missed_at: nil)
                            .where('GREATEST(conversations.created_at, conversations.status_changed_at) < ?', rule.waiting_time_minutes.minutes.ago),
               missed_at: Time.current)
  end

  # Pending in an inbox with a bot is the bot's conversation (see Custom::Message), not
  # a conversation waiting on the customer, so only agent inboxes auto-solve.
  def auto_solvable(conversations, inboxes, rule)
    conversations.pending.where(assignee_agent_bot_id: nil).where.not(inbox: inboxes.select(&:active_bot?))
                 .where("#{STATUS_CLOCK} < ?", rule.auto_solve_hours.hours.ago)
  end

  # Loading each row through the same scope with FOR UPDATE re-checks it once the row
  # is locked, so a conversation a customer reopened, or another run already moved,
  # is left alone. Orphans whose contact is being deleted fail validation, so they are
  # skipped as in Conversations::ResolutionJob; any other failure is reported and the
  # rest of the batch still moves.
  # A block runs on each locked conversation just before it moves, in the same transaction.
  # attrs is a status or the attributes to save.
  def transition(scope, attrs)
    attrs = { status: attrs } unless attrs.is_a?(Hash)
    scope = scope.where.not(contact_id: nil)
    scope.order(Arel.sql(STATUS_CLOCK)).limit(Limits::BULK_ACTIONS_LIMIT).ids.each do |id|
      Conversation.transaction do
        conversation = scope.lock.find_by(id: id)
        next unless conversation

        yield conversation if block_given?
        conversation.update!(attrs)
      end
    rescue ActiveRecord::RecordInvalid => e
      ChatwootExceptionTracker.new(e, account: e.record.account).capture_exception
    end
  end
end
