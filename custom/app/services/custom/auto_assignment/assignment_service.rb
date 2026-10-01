# Auto-assignment v2 picks from the inbox's online members (OSS and enterprise both pass
# them through filter_agents_by_team), so the project's entitled teams, the chat limit and developers narrow them here.
module Custom::AutoAssignment::AssignmentService
  private

  def filter_agents_by_team(agents, conversation)
    team_agents = super
    return team_agents if team_agents.nil?

    entitled_user_ids = inbox.project&.entitled_user_ids
    team_agents = team_agents.where(user_id: entitled_user_ids) if entitled_user_ids
    team_agents = team_agents.where.not(user_id: inbox.account.developer_user_ids)

    team_agents.where.not(user_id: inbox.user_ids_at_chat_limit(team_agents.pluck(:user_id)))
  end
end
