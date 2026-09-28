module Enterprise::V2::Reports::CdpDashboardBuilder
  private

  # Advanced assignment caps each agent per inbox through their capacity policy; across a
  # project the agent can hold the sum of the caps on its inboxes. Agents without a cap on
  # any of those inboxes keep the default limit.
  def agent_limits(user_ids)
    return super unless account.feature_enabled?('advanced_assignment')

    InboxCapacityLimit.joins(agent_capacity_policy: :account_users)
                      .where(inbox_id: inbox_ids, account_users: { account_id: account.id, user_id: user_ids })
                      .group('account_users.user_id')
                      .sum(:conversation_limit)
  end
end
