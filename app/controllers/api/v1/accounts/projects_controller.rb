class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  # inbox_ids and team_ids are not columns, so the default wrapper would drop them from
  # params[:project] and the client's selection would be silently ignored.
  wrap_parameters :project, include: Project.attribute_names + %w[inbox_ids team_ids]

  before_action :fetch_project, only: [:show, :update, :destroy, :avatar]
  before_action :check_authorization

  def index
    @projects = Current.account.projects.includes(:inboxes, :project_teams).order(:name)
  end

  def show; end

  def create
    @project = Current.account.projects.create!(project_params)
    sync_teams
    sync_inboxes
  end

  def update
    @project.update!(project_params)
    sync_teams
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

  # Same blank-entry convention as inbox_ids below.
  def sync_teams
    team_ids = params[:project][:team_ids]
    return if team_ids.nil?

    @project.teams = Current.account.teams.where(id: Array(team_ids).compact_blank)
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
    params.require(:project).permit(:name, :code, :description, :color, :avatar)
  end
end
