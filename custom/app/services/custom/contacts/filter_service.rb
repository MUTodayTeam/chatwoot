# Filters and segments start from the contacts the Contacts list shows (Custom::ContactScope), so a contact reached only
# through LINE, Facebook or Instagram stays in the list once a filter is applied, and crm_v2 still filters leads only.
# Account::ContactsExportJob filters through here too and runs as the requesting user, so a filtered export holds
# exactly the filtered list that user sees and never a contact they could not list.
module Custom::Contacts::FilterService
  def base_relation
    Custom::ContactScope.visible(@account.contacts, @user, @account)
  end
end
