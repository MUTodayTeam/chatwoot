# The signed-in agent's own status in this account: set it, and read it with the load against the
# chat limit and today's time per status. It only touches Current.account_user, so no policy.
class Api::V1::Accounts::AgentStatusController < Api::V1::Accounts::BaseController
  before_action :set_account_user
  before_action :set_project

  def show; end

  def update
    @account_user.update!(agent_status: params.require(:agent_status))
    render :show
  end

  private

  def set_account_user
    @account_user = Current.account_user
  end

  def set_project
    @project = Current.account.projects.find(params[:project_id]) if params[:project_id].present?
  end

  def agent_load
    inbox_ids = @project ? @project.inboxes.ids : Current.account.inboxes.ids
    Agents::ConversationLoadService.new(account: Current.account, inbox_ids: inbox_ids, user_ids: [@account_user.user_id],
                                        project: @project).perform.fetch(@account_user.user_id)
  end
  helper_method :agent_load
end
