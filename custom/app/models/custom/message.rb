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

  # A customer replying to a conversation an agent parked as pending hands it back to
  # that agent. Unassigned pending is how Chatwoot marks a bot's conversation (Captain,
  # agent bots, Dialogflow), so only a pending conversation with an agent and no AI
  # assignee is reopened.
  def reopen_conversation
    return super unless incoming? && agent_pending_conversation? && !conversation.muted?

    conversation.open!
  end

  def agent_pending_conversation?
    conversation.pending? && conversation.assignee_id.present? && conversation.ai_assignee.blank?
  end
end
