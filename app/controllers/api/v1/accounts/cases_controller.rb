class Api::V1::Accounts::CasesController < Api::V1::Accounts::BaseController
  before_action :fetch_case, only: [:show, :update]
  before_action :check_authorization

  def index
    result = CaseFinder.new(Current.user, Current.account, params).perform
    @cases = result[:cases]
    @count = result[:count]
    @open_count = result[:open_count]
  end

  def show; end

  # Status is the conversation's and changes from the conversation only
  def update
    @case.update!(case_params)
  end

  private

  def fetch_case
    @case = Case.where(account_id: Current.account.id).find(params[:id])
  end

  def check_authorization
    authorize(@case || Case)
  end

  def case_params
    params.require(:case).permit(:subject, :severity, :team_id)
  end
end
