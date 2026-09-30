# Unfiltered and label exports hold the contacts the Contacts list shows (Custom::ContactScope), as a filtered export
# already does through Contacts::FilterService, so a contact reached only through LINE, Facebook or Instagram is
# exported too. The scope runs for the requesting user, so an export never holds a contact that user could not list.
module Custom::Account::ContactsExportJob
  private

  def contacts
    return super if @params.present? && @params[:payload].present? && @params[:payload].any?

    visible = Custom::ContactScope.visible(@account.contacts, @account_user, @account)
    @params[:label].present? ? visible.tagged_with(@params[:label], any: true) : visible
  end
end
