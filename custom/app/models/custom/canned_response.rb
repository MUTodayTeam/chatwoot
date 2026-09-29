# A project scopes a canned response to the chats of that project's inboxes; without one
# it stays available everywhere, as in stock Chatwoot.
module Custom::CannedResponse
  def self.prepended(base)
    base.class_eval do
      belongs_to :project, optional: true
      validate :project_in_account
    end
  end

  private

  def project_in_account
    return if project_id.nil? || project&.account_id == account_id

    errors.add(:project, I18n.t('errors.canned_responses.project_account_mismatch'))
  end
end
