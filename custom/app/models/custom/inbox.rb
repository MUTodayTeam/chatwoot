# When the inbox's project has entitled teams, only their members can take its chats:
# admins lose the stock bypass unless they are in one of those teams. Stock
# assignable_agents stays as is, because it also decides who can be a participant.
# Agents who already hold the project's chat limit (live chat rule), and developers, are not offered new chats either.
module Custom::Inbox
  def entitled_assignable_agents
    entitled_user_ids = project&.entitled_user_ids
    return assignable_agents if entitled_user_ids.nil?

    account.users.where(id: members.select(:user_id)).where(id: entitled_user_ids)
  end

  def member_ids_with_assignment_capacity
    user_ids = super
    entitled_user_ids = project&.entitled_user_ids
    user_ids &= entitled_user_ids if entitled_user_ids
    user_ids -= account.developer_user_ids

    user_ids - user_ids_at_chat_limit(user_ids)
  end

  # The load is counted across the whole project, not just this inbox (CDP spec §15).
  def user_ids_at_chat_limit(user_ids)
    inbox_ids = project ? project.inboxes.ids : [id]
    loads = Agents::ConversationLoadService.new(account: account, inbox_ids: inbox_ids, user_ids: user_ids, project: project).perform
    loads.select { |_user_id, load| load[:assigned_count] >= load[:limit] }.keys
  end
end
