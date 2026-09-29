module Custom::Api::V1::Accounts::ContactsController
  # Also matches the hotel: company name, or the Partner ID custom attribute Contact 360 edits
  def search
    return render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank?

    contacts = Current.account.contacts.where(
      'name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR contacts.identifier LIKE :search ' \
      "OR contacts.additional_attributes->>'company_name' ILIKE :search " \
      "OR contacts.custom_attributes->>'#{Contacts::CdpAttributesSeeder::PARTNER_ID_KEY}' ILIKE :search",
      search: "%#{params[:q].strip}%"
    )
    @contacts = fetch_contacts_with_has_more(contacts)
  end

  private

  # Contacts reached only through LINE, Facebook or Instagram carry no email, phone or identifier, which stock treats as unresolved.
  # A contact is listed when the user can see one of its conversations; project_id narrows that to the project's inboxes.
  def resolved_contacts
    return @resolved_contacts if @resolved_contacts

    contacts = Current.account.contacts.merge(Contact.resolved_contacts.or(Contact.where(id: visible_conversations.select(:contact_id))))
    contacts = contacts.tagged_with(params[:labels], any: true) if params[:labels].present?
    @resolved_contacts = in_project(contacts)
  end

  def fetch_contacts_with_has_more(contacts)
    super(in_project(contacts))
  end

  def in_project(contacts)
    return contacts if params[:project_id].blank?

    inbox_ids = Current.account.inboxes.where(project_id: params[:project_id]).select(:id)
    contacts.where(id: visible_conversations.where(inbox_id: inbox_ids).select(:contact_id))
  end

  def visible_conversations
    Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
  end
end
