module Custom::Api::V1::Accounts::ContactsController
  private

  # project_id narrows the list and the search to contacts with a conversation in one of the project's inboxes
  def resolved_contacts
    @resolved_contacts ||= in_project(super)
  end

  def fetch_contacts_with_has_more(contacts)
    super(in_project(contacts))
  end

  def in_project(contacts)
    return contacts if params[:project_id].blank?

    inbox_ids = Current.account.inboxes.where(project_id: params[:project_id]).select(:id)
    contacts.where(id: Current.account.conversations.where(inbox_id: inbox_ids).select(:contact_id))
  end
end
