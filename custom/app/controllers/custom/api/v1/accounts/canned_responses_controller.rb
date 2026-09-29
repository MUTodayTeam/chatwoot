module Custom::Api::V1::Accounts::CannedResponsesController
  private

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :project_id)
  end

  # project_id narrows the list to that project's responses plus the ones shared by every project
  def canned_responses
    return super if params[:project_id].blank?

    super.where(project_id: [params[:project_id], nil])
  end
end
