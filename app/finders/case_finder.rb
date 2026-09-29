class CaseFinder
  RESULTS_PER_PAGE = 25
  LIST_INCLUDES = [
    :project, :team, :case_category, :resolved_by,
    { conversation: [:inbox, { assignee: { avatar_attachment: :blob } }, { contact: { avatar_attachment: :blob } }] }
  ].freeze

  def initialize(user, account, params)
    @user = user
    @account = account
    @params = params
  end

  def perform
    cases = filtered_cases
    {
      cases: cases.includes(LIST_INCLUDES).order(created_at: :desc, id: :desc).page(current_page).per(RESULTS_PER_PAGE),
      count: cases.count,
      open_count: cases.where(conversations: { status: Case::OPEN_STATUSES }).count
    }
  end

  private

  attr_reader :user, :account, :params

  # Agents see the cases of the conversations they can see, admins see them all
  def accessible_cases
    conversations = Conversations::PermissionFilterService.new(account.conversations, user, account).perform
    Case.where(account_id: account.id).joins(:conversation).where(conversation_id: conversations.select(:id))
  end

  def filtered_cases
    cases = accessible_cases.where(params.permit(:project_id, :team_id).compact_blank.to_h)
    cases = cases.where(conversations: { contact_id: params[:contact_id] }) if params[:contact_id].present?
    cases = cases.where(conversations: { status: statuses }) if params[:status].present?
    cases = mine(cases) if ActiveModel::Type::Boolean.new.cast(params[:mine])
    cases
  end

  def statuses
    params[:status] == 'active' ? Case::OPEN_STATUSES : params[:status]
  end

  # Owned by me, or one I had a turn on (handlers), so solved and reassigned cases stay in My Cases
  def mine(cases)
    handled = ConversationHandler.where(account_id: account.id, user_id: user.id).select(:conversation_id)
    cases.where(conversations: { assignee_id: user.id }).or(cases.where(conversation_id: handled))
  end

  def current_page
    params[:page] || 1
  end
end
