module Custom::Api::V1::Accounts::ContactsController
  private

  # Custom::ContactScope also lists the contacts reached only through LINE, Facebook or Instagram that the user can see;
  # project_id narrows the list to contacts with a conversation the user can see in one of the project's inboxes.
  def resolved_contacts
    return @resolved_contacts if @resolved_contacts

    contacts = Custom::ContactScope.visible(Current.account.contacts, Current.user, Current.account)
    contacts = contacts.tagged_with(params[:labels], any: true) if params[:labels].present?
    @resolved_contacts = in_project(contacts)
  end

  # Only search calls this: it also matches the hotel and lists the same contacts as the Contacts list
  def fetch_contacts_with_has_more(contacts)
    hotel = Current.account.contacts.where(Custom::ContactScope::HOTEL_SEARCH_CONDITION, search: "%#{params[:q].strip}%")
    super(in_project(Custom::ContactScope.visible(contacts.or(hotel), Current.user, Current.account)))
  end

  def in_project(contacts)
    return contacts if params[:project_id].blank?

    inbox_ids = Current.account.inboxes.where(project_id: params[:project_id]).select(:id)
    conversations = Conversations::PermissionFilterService.new(
      Current.account.conversations.where(inbox_id: inbox_ids), Current.user, Current.account
    ).perform
    contacts.where(id: conversations.select(:contact_id))
  end
end
