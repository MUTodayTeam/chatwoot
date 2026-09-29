# Auto-assignment v2 picks from the inbox's online members (OSS and enterprise both pass
# them through filter_agents_by_team), so the project's entitled teams narrow them here.
module Custom::AutoAssignment::AssignmentService
  private

  def filter_agents_by_team(agents, conversation)
    team_agents = super
    entitled_user_ids = inbox.project&.entitled_user_ids
    return team_agents if team_agents.nil? || entitled_user_ids.nil?

    team_agents.where(user_id: entitled_user_ids)
  end
end
