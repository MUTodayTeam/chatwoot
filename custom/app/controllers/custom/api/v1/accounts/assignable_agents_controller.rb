module Custom::Api::V1::Accounts::AssignableAgentsController
  # An agent is offered only if every selected inbox would accept them, which is the stock
  # list when no project has teams, so stock stays untouched in that case.
  def index
    super
    return unless ProjectTeam.exists?(project_id: @inboxes.map(&:project_id))

    @assignable_agents = @inboxes.map { |inbox| inbox.entitled_assignable_agents.to_a }.inject(:&)
  end
end
