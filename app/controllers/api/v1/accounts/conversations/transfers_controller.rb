# Transfer (spec 7.2): who the conversation can go to, and handing it over with a reason.
class Api::V1::Accounts::Conversations::TransfersController < Api::V1::Accounts::Conversations::BaseController
  rescue_from CustomExceptions::ConversationActionRefused, with: :render_error_response

  def show
    @team = Conversations::TransferService.transfer_team(@conversation)
    @agents = Conversations::TransferService.candidates(@conversation, Current.user, @team)
    @handler = @conversation.handlers.open.first
  end

  def create
    @assignee = Conversations::TransferService.new(
      conversation: @conversation,
      user: Current.user,
      assignee_id: params.require(:assignee_id),
      reason: params[:reason].presence || 'scope',
      note: params[:note]
    ).perform
  end
end
