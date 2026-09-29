module Custom::Api::V1::Accounts::AgentsController
  # The Agents settings list shows each agent's load across every inbox of the account (CDP spec §15).
  def index
    super
    @agent_loads = Agents::ConversationLoadService.new(account: Current.account, inbox_ids: Current.account.inboxes.pluck(:id),
                                                       user_ids: @agents.map(&:id)).perform
  end
end
