# Reopen (spec 7.4): an agent brings a Solved or Closed conversation back to Open.
class Api::V1::Accounts::Conversations::ReopensController < Api::V1::Accounts::Conversations::BaseController
  rescue_from CustomExceptions::ConversationActionRefused, with: :render_error_response

  def create
    Conversations::ReopenService.new(conversation: @conversation, user: Current.user).perform
  end
end
