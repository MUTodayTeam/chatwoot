module Custom::Api::V1::Accounts::ConversationsController
  # An agent who changes the status of a conversation nobody holds takes it first. The claim is its
  # own commit, so the handler listener opens their turn before a Solved or Closed can end it.
  def toggle_status
    Conversations::ClaimService.new(conversation: @conversation, user: Current.user).perform
    super
  end

  private

  # Stock hands the conversation to an agent who opens it, even from another agent. Here it stays
  # with whoever holds it; the claim above already gave an unassigned one to the agent.
  def handle_human_open
    @conversation.with_lock { @conversation.update!(ai_assignee: nil) }
  end
end
