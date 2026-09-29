module Custom::Api::V1::Accounts::AssignableAgentsController
  # An agent is offered only if every selected inbox would accept them, which is the stock
  # list when no project has teams, so stock stays untouched in that case.
  def index
    super
    if ProjectTeam.exists?(project_id: @inboxes.map(&:project_id))
      @assignable_agents = @inboxes.map { |inbox| inbox.entitled_assignable_agents.to_a }.inject(:&)
    end
    # The Assign dialog shows each agent's load across the whole project, not just this inbox (CDP spec §7.1).
    @agent_loads = Agents::ConversationLoadService.new(account: Current.account, inbox_ids: project_inbox_ids,
                                                       user_ids: @assignable_agents.map(&:id),
                                                       project: @inboxes.first&.project).perform
  end

  private

  def project_inbox_ids
    Current.account.inboxes.where(project_id: @inboxes.filter_map(&:project_id)).pluck(:id) | @inboxes.map(&:id)
  end
end
