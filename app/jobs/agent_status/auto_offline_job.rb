# Agents who stopped pinging (a closed laptop, a lost connection) go Offline, backdated to their
# last ping, so they pick Ready again on return instead of silently receiving chats. Agents who
# turned auto offline off are never swept; they stay as they set themselves.
class AgentStatus::AutoOfflineJob < ApplicationJob
  queue_as :scheduled_jobs

  OFFLINE_AFTER = ENV.fetch('AGENT_STATUS_OFFLINE_AFTER_MINUTES', 5).to_i.minutes

  def perform
    # A status that just began (a fresh login) still has the previous session's stale last ping
    switched_recently = AgentStatusEvent.open.where(started_at: OFFLINE_AFTER.ago..).pluck(:account_id, :user_id).to_set

    AccountUser.where(auto_offline: true).where.not(agent_status: :offline).find_each do |account_user|
      next if switched_recently.include?([account_user.account_id, account_user.user_id])

      last_ping = ::Redis::Alfred.zscore(OnlineStatusTracker.presence_key(account_user.account_id, 'User'), account_user.user_id)
      next if last_ping && last_ping > OFFLINE_AFTER.ago.to_i

      account_user.agent_status_changed_at = Time.zone.at(last_ping) if last_ping
      account_user.update!(agent_status: :offline)
    end
  end
end
