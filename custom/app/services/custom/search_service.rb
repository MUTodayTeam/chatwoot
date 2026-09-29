module Custom::SearchService
  private

  # A conversation is also found by its contact's hotel: the company name, or the Partner ID
  # custom attribute Contact 360 edits (Contacts::CdpAttributesSeeder::PARTNER_ID_KEY).
  def conversation_search_condition
    "#{super} OR contacts.additional_attributes->>'company_name' ILIKE :search " \
      "OR contacts.custom_attributes->>'#{Contacts::CdpAttributesSeeder::PARTNER_ID_KEY}' ILIKE :search"
  end
end
