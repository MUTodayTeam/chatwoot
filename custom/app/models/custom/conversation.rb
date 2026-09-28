module Custom::Conversation
  def self.prepended(base)
    base.class_eval do
      validate :closed_conversation_only_reopens, on: :update
    end
  end

  private

  # Closed is the end of the lifecycle: the only way out is reopening it. Resolving it
  # again would count a second resolution in the reports.
  def closed_conversation_only_reopens
    return unless status_changed? && status_was == 'closed' && !open?

    errors.add(:status, I18n.t('errors.conversations.closed_status_change'))
  end

  # Nothing waits on a reply once a conversation is closed, same as resolved.
  def handle_resolved_status_change
    super
    return unless saved_change_to_status? && closed?

    # rubocop:disable Rails/SkipsModelValidations
    update_columns(waiting_since: nil, reply_due_at: nil)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
