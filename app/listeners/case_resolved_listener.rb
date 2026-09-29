# The one place every resolve files its case, whichever path made it: toggle_status, the Select
# Category dialog, the list menu, bulk Solved or the auto-solve sweep (spec 7.3, 9.1 step 5).
# It runs on the sync dispatcher because the resolver is Current.user, which only the request
# or job that resolved knows. The rest of the case bookkeeping stays in the async CaseListener.
#
# The resolve is read from conversation_updated rather than conversation_resolved: that event
# is dispatched after the stock "resolved by" activity is queued, so "Solved" lands after it.
class CaseResolvedListener < BaseListener
  # The resolver is whoever resolved it, or the assignee when the system did (the sweep runs
  # without Current.user).
  def conversation_updated(event)
    return unless event.data[:changed_attributes]&.dig('status')&.last == 'resolved'

    conversation, = extract_conversation_and_account(event)
    resolver = Current.user.is_a?(User) ? Current.user : conversation.assignee
    kase = case_for(conversation, resolver, event.data[:performed_by])
    return if kase.nil?

    kase.update!(resolved_by: resolver)
    create_solved_activity(conversation, kase)
  end

  private

  # A case opens when an agent takes the conversation (spec 2.3), so one nobody took gets its
  # case only when an agent or the auto-solve sweep solves it, not when a bot, Captain or an
  # automation rule resolves it.
  def case_for(conversation, resolver, performed_by)
    return Case.ensure_for!(conversation, resolver) if resolver || performed_by.is_a?(LiveChatRule)

    Case.find_by(conversation_id: conversation.id)
  end

  # "Solved · topic · closes automatically in N hours"; a case without a category is Other
  def create_solved_activity(conversation, kase)
    account = conversation.account
    topic = kase.case_category&.c3 || I18n.t('conversations.activity.solved_other_topic', locale: account.locale)
    content = I18n.t('conversations.activity.solved', topic: topic, count: conversation.live_chat_rule.auto_close_hours, locale: account.locale)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
