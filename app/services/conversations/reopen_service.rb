# Reopen (spec 7.4, 9.1 step 3): an agent brings a Solved or Closed conversation back to Open.
# It goes back to its previous agent, or to the agent reopening it when it had none. The
# handler listener opens that agent's new turn and the case listener counts the reopen, both
# from the status change, as for a customer writing back.
class Conversations::ReopenService
  pattr_initialize [:conversation!, :user!]

  def perform
    conversation.with_lock do
      if ConversationHandler::FINISHED_STATUSES.exclude?(conversation.status)
        raise CustomExceptions::ConversationActionRefused.new(reason: :reopen_not_finished)
      end

      conversation.assignee ||= user
      conversation.update!(status: :open)
    end
  end
end
