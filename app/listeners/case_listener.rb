class CaseListener < BaseListener
  REOPENED_FROM = %w[resolved closed].freeze

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
    return unless status == 'open' && REOPENED_FROM.include?(previous_status)

    # rubocop:disable Rails/SkipsModelValidations
    Case.where(conversation_id: conversation.id).update_all('reopened_count = reopened_count + 1, updated_at = NOW()')
    # rubocop:enable Rails/SkipsModelValidations
  end
end
