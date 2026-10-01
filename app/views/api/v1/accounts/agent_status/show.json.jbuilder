json.agent_status @account_user.agent_status
json.availability @account_user.availability
json.since AgentStatusEvent.open.find_by(account_id: @account_user.account_id, user_id: @account_user.user_id)&.started_at
json.load do
  json.active agent_load[:assigned_count]
  json.limit agent_load[:limit]
end
json.today AgentStatusEvent.today_for(@account_user)
json.server_time Time.current
