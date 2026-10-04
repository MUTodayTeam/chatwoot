class AutoAssignOnReplyListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless agent_reply?(message)

    assign(message.conversation, message.sender)
  end

  private

  def agent_reply?(message)
    message.outgoing? && !message.private? && message.sender.is_a?(User) &&
      message.content_attributes['automation_rule_id'].blank? &&
      message.additional_attributes['campaign_id'].blank?
  end

  # Runs in a background job, so Current is blank here. The assignment activity message
  # names Current.user as the actor and is skipped without one. Unlike a status change, a
  # reply also opens a pending conversation it takes from a bot, which AssignmentService does.
  def assign(conversation, agent)
    return unless Conversations::ClaimService.new(conversation: conversation, user: agent).claimable?

    Current.user = agent
    Conversations::AssignmentService.new(conversation: conversation, assignee_id: agent.id).perform
  ensure
    Current.reset
  end
end
