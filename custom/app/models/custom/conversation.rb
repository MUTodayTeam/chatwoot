module Custom::Conversation
  def self.prepended(base)
    base.class_eval do
      validate :closed_status_transition
    end
  end

  # Closed is already past resolved, so muting a closed conversation only blocks the contact.
  def mute!
    return super unless closed?
    return unless contact

    contact.update(blocked: true)
    create_muted_message
  end

  private

  # Closed is the end of the lifecycle. It follows resolved, so the resolution is reported,
  # CSAT goes out and the resolved listeners run exactly once; the only way out is reopening.
  def closed_status_transition
    return unless will_save_change_to_status?

    if closed? && status_in_database != 'resolved'
      errors.add(:status, I18n.t('errors.conversations.closed_requires_resolved'))
    elsif status_in_database == 'closed' && !open?
      errors.add(:status, I18n.t('errors.conversations.closed_status_change'))
    end
  end
end
