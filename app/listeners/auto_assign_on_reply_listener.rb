class AutoAssignOnReplyListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    conversation = message.conversation

    return unless agent_reply?(message)
    return if conversation.assignee_id.present?
    return unless conversation.inbox.entitled_assignable_agents.include?(message.sender)

    assign(conversation, message.sender)
  end

  private

  def agent_reply?(message)
    message.outgoing? && !message.private? && message.sender.is_a?(User) &&
      message.content_attributes['automation_rule_id'].blank? &&
      message.additional_attributes['campaign_id'].blank?
  end

  # Runs in a background job, so Current is blank here. The assignment activity message
  # names Current.user as the actor and is skipped without one.
  def assign(conversation, agent)
    Current.user = agent
    Conversations::AssignmentService.new(conversation: conversation, assignee_id: agent.id).perform
  ensure
    Current.reset
  end
end
