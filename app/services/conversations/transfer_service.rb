# Transfer (spec 7.2): hands the conversation to a member of the project's transfer team with
# a reason. It works like Assign, except that the outgoing agent's turn ends with the chosen
# reason instead of "assign", which is what productivity credits: the outgoing agent keeps an
# Assisted, and a "general" handover costs them the transfer penalty.
class Conversations::TransferService
  pattr_initialize [:conversation!, :user!, :assignee_id!, :reason!, :note]

  def self.transfer_team(conversation)
    LiveChatRule.transfer_team_for(conversation.account, conversation.inbox.project)
  end

  # Everyone the user can hand the conversation to: the transfer team, without the user and
  # whoever already has it
  def self.candidates(conversation, user, team = transfer_team(conversation))
    return User.none unless team

    team.members.where.not(id: [user.id, conversation.assignee_id].compact).order(:name)
  end

  def perform
    team = self.class.transfer_team(conversation)
    refuse!(:transfer_team_missing) unless team
    refuse!(:transfer_reason_invalid) unless ConversationHandler::TRANSFER_REASONS.include?(reason)

    assignee = hand_over(team)
    create_note
    assignee
  end

  private

  # The turn closes in the same transaction as the assignment and before it, so the handler
  # listener only has the incoming agent's turn left to open. The assignee is checked against
  # the row the lock reloaded: a second tab or a retried request that loaded the conversation
  # earlier must not end the turn someone else has just been handed.
  def hand_over(team)
    conversation.with_lock do
      refuse!(:transfer_finished) if ConversationHandler::FINISHED_STATUSES.include?(conversation.status)
      assignee = self.class.candidates(conversation, user, team).find_by(id: assignee_id)
      refuse!(:transfer_assignee_invalid) unless assignee

      ConversationHandler.close_open!(conversation, reason: reason, ended_by: user, note: note)
      conversation.transfer_reason = reason
      Conversations::AssignmentService.new(conversation: conversation, assignee_id: assignee.id).perform
      assignee
    end
  end

  # The incoming agent reads the note in the thread, where the customer cannot see it
  def create_note
    return if note.blank?

    conversation.messages.create!(
      account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing, private: true, sender: user, content: note
    )
  end

  def refuse!(reason_key)
    raise CustomExceptions::ConversationActionRefused.new(reason: reason_key)
  end
end
