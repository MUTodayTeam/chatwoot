# A transfer or reopen that the conversation's state or the live chat rules do not allow
class CustomExceptions::ConversationActionRefused < CustomExceptions::Base
  def message
    I18n.t("errors.conversations.#{@data[:reason]}")
  end

  def http_status
    422
  end
end
