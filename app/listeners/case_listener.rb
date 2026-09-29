class CaseListener < BaseListener
  REOPENED_FROM = %w[resolved closed].freeze
  # A bot inbox hands a reopened conversation back to the bot, which is pending
  REOPENED_TO = %w[open pending].freeze

  # An agent taking a conversation opens its case, whichever path assigned it.
  def assignee_changed(event)
    conversation, = extract_conversation_and_account(event)
    return if conversation.assignee.blank?

    Case.ensure_for!(conversation, conversation.assignee)
  end

  # The customer (or an agent) coming back to a Solved or Closed conversation reopens its case.
  # conversation_opened carries no changes, so the status change is read from this event.
  def conversation_updated(event)
    conversation, = extract_conversation_and_account(event)
    previous_status, status = event.data[:changed_attributes]&.dig('status')
    return unless REOPENED_TO.include?(status) && REOPENED_FROM.include?(previous_status)

    # rubocop:disable Rails/SkipsModelValidations
    Case.where(conversation_id: conversation.id).update_all('reopened_count = reopened_count + 1, updated_at = NOW()')
    # rubocop:enable Rails/SkipsModelValidations
  end

  # A case opened before the customer wrote (an agent started the chat) takes its subject
  # from the customer's first message once it arrives.
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming?

    Case.find_by(conversation_id: message.conversation_id, subject: '')&.update!(subject: Case.subject_from(message))
  end
end
