class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  # inbox_ids is not a column, so the default wrapper would drop it from params[:project]
  # and the client's inbox selection would be silently ignored.
  wrap_parameters :project, include: Project.attribute_names + ['inbox_ids']

  before_action :fetch_project, only: [:show, :update, :destroy, :avatar]
  before_action :check_authorization

  def index
    @projects = Current.account.projects.order(:name)
  end

  def show; end

  def create
    @project = Current.account.projects.create!(project_params)
    sync_inboxes
  end

  def update
    @project.update!(project_params)
    sync_inboxes
  end

  def destroy
    @project.destroy!
    head :ok
  end

  def avatar
    @project.avatar.purge if @project.avatar.attached?
    render 'api/v1/accounts/projects/show'
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  # Which inboxes belong to a project is edited from the project itself, so the
  # admin picks them in one place instead of visiting every inbox's settings.
  def sync_inboxes
    inbox_ids = params[:project][:inbox_ids]
    return if inbox_ids.nil?

    # A multipart form cannot send an empty array, so it sends one blank entry to
    # say "no inboxes". Dropping blanks turns that back into an empty selection.
    inbox_ids = Array(inbox_ids).compact_blank
    inboxes = Current.account.inboxes
    inboxes.where(project_id: @project.id).where.not(id: inbox_ids).find_each { |inbox| inbox.update!(project: nil) }
    inboxes.where(id: inbox_ids).find_each { |inbox| inbox.update!(project: @project) }
    @project.reload
  end

  def project_params
    params.require(:project).permit(:name, :description, :color, :avatar)
  end
end
