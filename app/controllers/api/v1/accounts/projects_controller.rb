class Api::V1::Accounts::ProjectsController < Api::V1::Accounts::BaseController
  before_action :fetch_project, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @projects = Current.account.projects.order(:name)
  end

  def show; end

  def create
    @project = Current.account.projects.create!(project_params)
  end

  def update
    @project.update!(project_params)
  end

  def destroy
    @project.destroy!
    head :ok
  end

  private

  def fetch_project
    @project = Current.account.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :color)
  end
end
