# What Contact 360 shows about a contact across every project, limited to the conversations the user can see
class Api::V1::Accounts::Contacts::OverviewsController < Api::V1::Accounts::Contacts::BaseController
  HISTORY_LIMIT = 6
  HISTORY_STATUSES = %w[resolved closed].freeze

  def show
    conversations = Conversations::PermissionFilterService.new(
      Current.account.conversations.where(contact_id: @contact.id),
      Current.user,
      Current.account
    ).perform

    @conversations_count = conversations.count
    @first_contact_at = conversations.minimum(:created_at)
    @latest_conversation = conversations.order(created_at: :desc, id: :desc).first
    @history = conversations.where(status: HISTORY_STATUSES)
                            .includes(:assignee, { inbox: :project }, case: :resolved_by)
                            .order(created_at: :desc, id: :desc)
                            .limit(HISTORY_LIMIT)
  end
end
