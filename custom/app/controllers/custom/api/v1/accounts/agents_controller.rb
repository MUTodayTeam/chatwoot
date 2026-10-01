module Custom::Api::V1::Accounts::AgentsController
  # The Agents settings list shows each agent's load across every inbox of the account (CDP spec §15).
  # Every agent can read this list, so the load goes only to those who may see the reports it comes from.
  def index
    super
    return unless policy(:report).view?

    @agent_loads = Agents::ConversationLoadService.new(account: Current.account, inbox_ids: Current.account.inboxes.pluck(:id),
                                                       user_ids: @agents.map(&:id)).perform
  end

  private

  # Only administrators reach update (UserPolicy), so only they can mark a developer.
  def account_user_attributes
    super + [:developer]
  end

  def allowed_agent_params
    super + [:developer]
  end
end
