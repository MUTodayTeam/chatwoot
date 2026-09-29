module Custom::SearchService
  private

  # A conversation is also found by its contact's hotel: the company name, or the Partner ID
  # custom attribute Contact 360 edits (Contacts::CdpAttributesSeeder::PARTNER_ID_KEY).
  def conversation_search_condition
    "#{super} OR #{hotel_search_condition('contacts')}"
  end

  # Same for contacts, and one reached only through LINE or Facebook (no email, phone or identifier) is still listed
  # when the user can see one of its conversations.
  def filter_contacts
    contacts_query = current_account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR identifier ILIKE :search OR #{hotel_search_condition('contacts')}",
      search: "%#{search_query}%"
    )
    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    seen = current_account.conversations.where(inbox_id: accessable_inbox_ids).select(:contact_id)
    resolved = Contact.resolved_contacts(use_crm_v2: current_account.feature_enabled?('crm_v2')).or(Contact.where(id: seen))
    @contacts = contacts_query.merge(resolved).order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def hotel_search_condition(table)
    "#{table}.additional_attributes->>'company_name' ILIKE :search " \
      "OR #{table}.custom_attributes->>'#{Contacts::CdpAttributesSeeder::PARTNER_ID_KEY}' ILIKE :search"
  end
end
