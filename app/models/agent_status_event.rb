# == Schema Information
#
# Table name: agent_status_events
#
#  id           :bigint           not null, primary key
#  agent_status :integer          not null
#  ended_at     :datetime
#  started_at   :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_agent_status_events_on_account_user_started_at  (account_id,user_id,started_at)
#  index_agent_status_events_open_per_user               (account_id,user_id) UNIQUE WHERE (ended_at IS NULL)
#
# One stretch an agent spent in a status. The status menu's "today" summary adds them up.
class AgentStatusEvent < ApplicationRecord
  # Offline is not counted as online time
  ONLINE_STATUSES = %w[ready busy mini_break lunch briefing rest_room].freeze
  # An agent who has just switched to Ready gets no chats from auto-assignment for this long. What
  # they reply to or change the status of is still theirs at once (Conversations::ClaimService).
  READY_COOLDOWN = 5.minutes

  belongs_to :account
  belongs_to :user

  enum :agent_status, AccountUser::AGENT_STATUSES, prefix: true

  scope :open, -> { where(ended_at: nil) }

  # Closes the open interval and opens the next one. The partial unique index allows one open
  # interval per agent, so of two writers at once one inserts and the other returns nil.
  def self.switch!(account_user, status, at: Time.current)
    transaction(requires_new: true) do
      current = open.find_by(account_id: account_user.account_id, user_id: account_user.user_id)
      next if current&.agent_status == status.to_s

      at = [at, current.started_at].max if current
      current&.update!(ended_at: at)
      create!(account_id: account_user.account_id, user_id: account_user.user_id, agent_status: status, started_at: at)
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # Agents who switched to Ready from another status within the cool-down. A new agent starts Ready
  # with no earlier interval, so joining the account is not a switch.
  def self.ready_cooling_down_user_ids(account_id, now: Time.current)
    open.agent_status_ready.where(account_id: account_id).where('started_at > ?', now - READY_COOLDOWN)
        .where(<<~SQL.squish).pluck(:user_id)
          EXISTS (SELECT 1 FROM agent_status_events previous
                  WHERE previous.account_id = agent_status_events.account_id
                    AND previous.user_id = agent_status_events.user_id
                    AND previous.ended_at = agent_status_events.started_at)
        SQL
  end

  scope :overlapping, lambda { |account_user, from, to|
    where(account_id: account_user.account_id, user_id: account_user.user_id)
      .where('ended_at IS NULL OR ended_at > ?', from).where('started_at < ?', to)
  }

  # Seconds the agent spent in each status since the account's midnight (reporting timezone, UTC
  # when unset), plus the online total. An interval that began before midnight counts from it.
  def self.today_for(account_user, now: Time.current)
    zone = ActiveSupport::TimeZone[account_user.account.reporting_timezone.presence || 'UTC']
    day_start = now.in_time_zone(zone).beginning_of_day
    seconds = ONLINE_STATUSES.index_with { 0 }

    overlapping(account_user, day_start, now).find_each do |event|
      next unless seconds.key?(event.agent_status)

      seconds[event.agent_status] += ([event.ended_at || now, now].min - [event.started_at, day_start].max).to_i
    end

    seconds.symbolize_keys.merge(online_total: seconds.values.sum)
  end
end
