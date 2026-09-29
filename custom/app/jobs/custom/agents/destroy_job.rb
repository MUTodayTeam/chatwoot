# Removing an agent unassigns their conversations with update_all, which fires no
# ASSIGNEE_CHANGED, so their turns are ended here or they would stay open and take the credit
# when someone else solves the conversation.
module Custom::Agents::DestroyJob
  private

  def unassign_conversations(account, user)
    # rubocop:disable Rails/SkipsModelValidations
    ConversationHandler.open.where(account_id: account.id, user_id: user.id)
                       .update_all(ended_at: Time.current, end_reason: ConversationHandler.end_reasons[:unassigned], updated_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    super
  end
end
