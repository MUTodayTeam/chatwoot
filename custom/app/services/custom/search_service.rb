module Custom::SearchService
  private

  # A conversation is also found by its contact's hotel
  def conversation_search_condition
    "#{super} OR #{Custom::ContactScope::HOTEL_SEARCH_CONDITION}"
  end

  # Same for contacts, and the list is the Contacts list's (Custom::ContactScope). Stock builds the search and applies
  # resolved_contacts inside this one method with no seam to hook, so the body is replaced rather than wrapped.
  def filter_contacts
    contacts_query = current_account.contacts.where(
      'name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR identifier ILIKE :search ' \
      "OR #{Custom::ContactScope::HOTEL_SEARCH_CONDITION}",
      search: "%#{search_query}%"
    )
    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    @contacts = Custom::ContactScope.visible(contacts_query, current_user, current_account)
                                    .order_on_last_activity_at('desc').page(params[:page]).per(15)
  end
end
