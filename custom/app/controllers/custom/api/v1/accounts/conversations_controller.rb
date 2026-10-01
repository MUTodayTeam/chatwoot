module Custom::Api::V1::Accounts::ConversationsController
  private

  # Stock gives the conversation to whoever opens it. A developer who opens one to look at it
  # would be assigned without choosing to be, so they leave it with whoever holds it; the
  # Assign dialog still hands them one on purpose.
  def handle_human_open
    return super unless Current.account.developer_user_ids.include?(Current.user.id)

    @conversation.with_lock { @conversation.update!(ai_assignee: nil) }
  end
end
