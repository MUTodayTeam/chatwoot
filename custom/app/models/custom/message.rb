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
  # reopened it. Each step locks the row and goes ahead only while the conversation is still
  # finished, so a burst of customer messages reopens it, and hands it over, once.
  def reopen_for_customer
    hand_to_online_teammate
    conversation.with_lock do
      next unless finished_conversation?

      Current.executed_by = sender if reopened_by_contact?
      conversation.open!
    end
  end

  # An offline agent's conversation goes to an online teammate from its team (spec 9.1), and
  # stays with the agent when nobody is online. It is a save of its own, marked the way the
  # inbox's auto-assignment marks one, so the timeline shows the handover.
  def hand_to_online_teammate
    conversation.with_lock do
      next unless finished_conversation? && assignee_offline?

      teammate = online_teammate
      next unless teammate

      Current.executed_by = conversation.inbox.assignment_policy || conversation.inbox
      conversation.update!(assignee: teammate)
    end
  ensure
    Current.executed_by = nil
  end

  def finished_conversation?
    conversation.resolved? || conversation.closed?
  end

  def assignee_offline?
    conversation.assignee.present? &&
      conversation.account.account_users.find_by(user_id: conversation.assignee_id)&.availability_status == 'offline'
  end

  def online_teammate
    candidate_ids = conversation.inbox.member_ids_with_assignment_capacity
    candidate_ids &= conversation.team.members.ids if conversation.team
    AutoAssignment::AgentAssignmentService.new(conversation: conversation, allowed_agent_ids: candidate_ids).find_assignee
  end

  # An agent answering a conversation an agent bot or Dialogflow holds takes it from the bot
  # (spec 17). An entitled agent nobody assigned takes it first, as AutoAssignOnReplyListener
  # would, so opening it never runs the inbox's round robin and hands it to someone else.
  def mark_pending_conversation_as_open_for_human_response
    return super if captain_pending_conversation?
    return unless conversation.pending? && conversation.inbox.active_bot? && human_response? && !private?

    conversation.update!(assignee: sender) if unassigned_for_entitled_sender?
    open_for_agent_reply
  end

  def unassigned_for_entitled_sender?
    conversation.assignee.blank? && conversation.inbox.entitled_assignable_agents.include?(sender)
  end

  # Written the way Enterprise writes an agent taking a conversation from Captain: one
  # activity that says the reply opened it, not "reopened by" the agent.
  def open_for_agent_reply
    previous_user = Current.user
    previous_executed_by = Current.executed_by
    Current.user = nil
    Current.executed_by = nil
    conversation.update!(status: :open, ai_assignee: nil)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity,
      content: I18n.t('conversations.activity.captain.auto_opened_after_agent_reply', locale: conversation.account.locale),
      content_attributes: { activity: { type: 'conversation_status_changed', status: 'open' } }
    )
  ensure
    Current.user = previous_user
    Current.executed_by = previous_executed_by
  end

  # Pending is also how Chatwoot hands a conversation to a bot (Captain, agent bots,
  # Dialogflow), and a bot inbox reopens a resolved conversation nobody took as pending,
  # so in a bot inbox pending stays with the bot unless an agent holds it (spec 3).
  def agent_pending_conversation?
    conversation.pending? && conversation.ai_assignee.blank? && (conversation.assignee.present? || !conversation.inbox.active_bot?)
  end
end
