# Solved from the Select Category dialog: resolve, file the case under a category, and choose
# whether this resolve sends the CSAT survey. Resolving without a category stays the stock
# toggle_status, whose case counts as "Other".
class Api::V1::Accounts::Conversations::SolvesController < Api::V1::Accounts::Conversations::BaseController
  def create
    return render_could_not_create_error(I18n.t('errors.conversations.already_resolved')) if @conversation.resolved?

    @case = Conversations::SolveService.new(
      conversation: @conversation,
      user: Current.user,
      case_category: case_category,
      summary: params[:summary],
      send_survey: params.key?(:send_survey) ? ActiveModel::Type::Boolean.new.cast(params[:send_survey]) : true
    ).perform
  end

  private

  def case_category
    CaseCategory.where(account_id: Current.account.id).find(params[:case_category_id]) if params[:case_category_id].present?
  end
end
