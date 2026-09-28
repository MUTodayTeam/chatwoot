# When the inbox's project has entitled teams, only their members can take its chats:
# admins lose the stock bypass unless they are in one of those teams.
module Custom::Inbox
  def assignable_agents
    entitled_user_ids = project&.entitled_user_ids
    return super if entitled_user_ids.nil?

    account.users.where(id: members.select(:user_id)).where(id: entitled_user_ids)
  end

  def member_ids_with_assignment_capacity
    entitled_user_ids = project&.entitled_user_ids
    return super if entitled_user_ids.nil?

    super & entitled_user_ids
  end
end
