# Keeps conversation_handlers in step with who looks after a conversation (spec 2.2, 7.1, 9.1).
# It runs on the sync dispatcher, so turns follow the order of the commits that changed them.
#
# Transfer, Solved and the auto-solve close the turn themselves, with their own reason, before
# they change the conversation. By the time their event arrives here the turn is already
# closed, so nothing is closed twice: every step below only acts on the open turn, and a
# repeated event finds the work done.
class ConversationHandlerListener < BaseListener
  def assignee_changed(event)
    conversation, = extract_conversation_and_account(event)
    return if ConversationHandler::FINISHED_STATUSES.include?(conversation.status)

    hand_over(conversation, event.timestamp)
  end

  def conversation_resolved(event)
    conversation, = extract_conversation_and_account(event)
    ConversationHandler.close_open!(conversation, reason: :solved, ended_by: Current.user, at: event.timestamp)
  end

  # Reopened after Solved or Closed, by the customer or an agent. conversation_opened carries
  # no changes, so the status change is read from this event.
  def conversation_updated(event)
    conversation, = extract_conversation_and_account(event)
    previous_status, status = event.data[:changed_attributes]&.dig('status')
    return unless ConversationHandler::FINISHED_STATUSES.include?(previous_status) && ConversationHandler::FINISHED_STATUSES.exclude?(status)

    hand_over(conversation, event.timestamp)
  end

  private

  # Ends whichever turn is open unless it already belongs to the assignee, then starts the
  # assignee's turn. Only agents have turns; a bot or nobody leaves none open.
  def hand_over(conversation, at)
    open_user_id = ConversationHandler.open.where(conversation_id: conversation.id).pick(:user_id)
    return if open_user_id.present? && open_user_id == conversation.assignee_id

    if open_user_id
      reason = conversation.assignee_id ? :assign : :unassigned
      ConversationHandler.close_open!(conversation, reason: reason, ended_by: Current.user, at: at)
    end
    ConversationHandler.open_for!(conversation, conversation.assignee, at: at) if conversation.assignee_id
  end
end
