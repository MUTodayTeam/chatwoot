# The Contacts list, contact search and global search list the same contacts through this module.
module Custom::ContactScope
  # The hotel: the company name, or the Partner ID custom attribute Contact 360 edits
  HOTEL_SEARCH_CONDITION = "contacts.additional_attributes->>'company_name' ILIKE :search " \
                           "OR contacts.custom_attributes->>'#{Contacts::CdpAttributesSeeder::PARTNER_ID_KEY}' ILIKE :search".freeze

  # Stock lists a contact once it has an email, phone number or identifier. Contacts reached only through LINE, Facebook
  # or Instagram have none of these, so they are also listed when the user can see one of their conversations. crm_v2
  # lists leads only, exactly like stock. EXISTS keeps the widening on the conversations contact index.
  def self.visible(contacts, user, account)
    return contacts.resolved_contacts(use_crm_v2: true) if account.feature_enabled?('crm_v2')

    conversations = account.conversations.where('conversations.contact_id = contacts.id')
    seen = Conversations::PermissionFilterService.new(conversations, user, account).perform

    contacts.resolved_contacts.or(contacts.where('EXISTS (?)', seen.select(1)))
  end
end
