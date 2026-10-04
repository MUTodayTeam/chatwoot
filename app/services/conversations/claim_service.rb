# An agent who acts on a conversation nobody holds takes it: a public reply (AutoAssignOnReplyListener)
# or a status change (toggle_status, Solved). One another agent holds stays theirs, and a bot-only
# holder is taken over. Developers never take one this way, and only agents entitled to the inbox do.
class Conversations::ClaimService
  pattr_initialize [:conversation!, :user!]

  # Leaves the status alone: a status change claims first, then sets the status it asked for
  def perform
    return unless claimable?

    conversation.with_lock do
      next if conversation.assignee_id.present?

      conversation.update!(assignee: user, ai_assignee: nil)
    end
  end

  def claimable?
    user.is_a?(User) && conversation.assignee_id.blank? &&
      conversation.account.developer_user_ids.exclude?(user.id) &&
      conversation.inbox.entitled_assignable_agents.include?(user)
  end
end
