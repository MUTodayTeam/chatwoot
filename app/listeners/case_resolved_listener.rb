# The one place every resolve files its case, whichever path made it: toggle_status, the Select
# Category dialog, the list menu, bulk Solved or the auto-solve sweep (spec 7.3, 9.1 step 5).
# It runs on the sync dispatcher because the resolver is Current.user, which only the request
# or job that resolved knows. The rest of the case bookkeeping stays in the async CaseListener.
class CaseResolvedListener < BaseListener
  # A conversation nobody took gets its case now. The resolver is whoever resolved it, or the
  # assignee when the system did (the sweep runs without Current.user).
  def conversation_resolved(event)
    conversation, = extract_conversation_and_account(event)
    resolver = Current.user.is_a?(User) ? Current.user : conversation.assignee

    kase = Case.ensure_for!(conversation, resolver)
    kase.update!(resolved_by: resolver)
    create_solved_activity(conversation, kase)
  end

  private

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
