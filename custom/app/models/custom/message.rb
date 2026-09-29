module Custom::Message
  def self.prepended(base)
    base.class_eval do
      validate :conversation_accepts_outgoing_message, on: :create, if: :outgoing?
    end
  end

  private

  # A closed conversation is read-only: the customer's next message starts a new one.
  def conversation_accepts_outgoing_message
    errors.add(:base, I18n.t('errors.conversations.closed')) if conversation&.closed?
  end

  # A customer replying to a pending conversation hands it back to the agents.
  # LINE, Facebook, Instagram and TikTok start a new conversation after closed, so a
  # closed one only gets here on the other channels; reopen it so the message is seen.
  def reopen_conversation
    return super unless incoming? && !conversation.muted? && (conversation.closed? || agent_pending_conversation?)
    return conversation.open! unless conversation.closed?

    reopen_for_customer
  end

  # A customer writing back to a Solved conversation brings it back to its agent, in a bot
  # inbox too (spec 3, 9.1 step 3). Only one nobody took goes back to the bot, as in stock.
  def reopen_resolved_conversation
    return reopen_for_customer if conversation.assignee.present?

    Current.executed_by = sender if reopened_by_contact?
    super
  end

  # Marked the way Chatwoot marks an API inbox's reopen, so the timeline says the customer
  # reopened it. An offline agent's conversation goes to an online teammate, and stays with
  # the agent when nobody is online.
  def reopen_for_customer
    Current.executed_by = sender if reopened_by_contact?
    conversation.assignee = online_teammate || conversation.assignee if assignee_offline?
    conversation.open!
  end

  def assignee_offline?
    conversation.assignee.present? &&
      conversation.account.account_users.find_by(user_id: conversation.assignee_id)&.availability_status == 'offline'
  end

  def online_teammate
    AutoAssignment::AgentAssignmentService.new(
      conversation: conversation, allowed_agent_ids: conversation.inbox.member_ids_with_assignment_capacity
    ).find_assignee
  end

  # An agent answering a conversation an agent bot or Dialogflow holds takes it from the bot
  # (spec 17), as Enterprise already does for Captain with its own activity.
  def mark_pending_conversation_as_open_for_human_response
    return super if captain_pending_conversation?
    return unless conversation.pending? && conversation.inbox.active_bot? && human_response? && !private?

    conversation.update!(status: :open, ai_assignee: nil)
  end

  # Pending is also how Chatwoot hands a conversation to a bot (Captain, agent bots,
  # Dialogflow), and a bot inbox reopens a resolved conversation as pending, so pending
  # stays with the bot whenever the inbox has one.
  def agent_pending_conversation?
    conversation.pending? && conversation.ai_assignee.blank? && !conversation.inbox.active_bot?
  end
end
