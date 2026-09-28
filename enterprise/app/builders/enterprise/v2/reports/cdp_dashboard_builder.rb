module Enterprise::V2::Reports::CdpDashboardBuilder
  private

  # Advanced assignment caps each agent per inbox through their capacity policy. Inboxes without a
  # cap are unlimited for auto-assignment (Enterprise::AutoAssignment::CapacityService), so they
  # are left out of both the agent's load and limit. Agents without a cap on any project inbox keep the default limit.
  def agent_inbox_limits(user_ids)
    return super unless account.feature_enabled?('advanced_assignment')

    InboxCapacityLimit.joins(agent_capacity_policy: :account_users)
                      .where(inbox_id: inbox_ids, account_users: { account_id: account.id, user_id: user_ids })
                      .pluck('account_users.user_id', :inbox_id, :conversation_limit)
                      .each_with_object({}) do |(user_id, inbox_id, limit), result|
                        (result[user_id] ||= {})[inbox_id] = limit
                      end
  end
end
