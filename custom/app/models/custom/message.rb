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

    conversation.open!
  end

  # Pending is also how Chatwoot hands a conversation to a bot (Captain, agent bots,
  # Dialogflow), and a bot inbox reopens a resolved conversation as pending, so pending
  # stays with the bot whenever the inbox has one.
  def agent_pending_conversation?
    conversation.pending? && conversation.ai_assignee.blank? && !conversation.inbox.active_bot?
  end
end
