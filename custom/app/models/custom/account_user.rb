# The Thaimart CDP status set: Ready, Busy, Mini break, Lunch, Briefing / Coaching, Rest room
# and Offline. Only Ready gets chats assigned automatically.
#
# Stock `availability` (online, busy, offline) stays the field every assignment and presence
# path reads, so it is derived from the status: Ready is online, Offline is offline and the
# four away statuses are busy. A stock writer (the mobile apps, an admin, AgentBuilder) that
# sets availability maps back to Ready, Busy or Offline.
module Custom::AccountUser
  AGENT_STATUSES = { ready: 0, busy: 1, mini_break: 2, lunch: 3, briefing: 4, rest_room: 5, offline: 6 }.freeze
  AVAILABILITY_BY_STATUS = AGENT_STATUSES.keys.index_with { 'busy' }.merge(ready: 'online', offline: 'offline').stringify_keys.freeze
  STATUS_BY_AVAILABILITY = { 'online' => 'ready', 'busy' => 'busy', 'offline' => 'offline' }.freeze

  def self.prepended(base)
    base.class_eval do
      # Prefixed: a bare `busy?` or `offline?` would collide with the availability enum
      enum :agent_status, AGENT_STATUSES, prefix: true, validate: true

      # The sweep backdates a change to the agent's last ping
      attr_accessor :agent_status_changed_at

      before_save :sync_status_and_availability
      after_create :open_agent_status_event
      after_update :switch_agent_status_event, if: :saved_change_to_agent_status?
      after_update_commit :assign_waiting_chats_after_ready_cooldown, if: -> { saved_change_to_agent_status? && agent_status_ready? }
      after_destroy :close_agent_status_event
    end
  end

  private

  def sync_status_and_availability
    if agent_status_changed?
      self.availability = AVAILABILITY_BY_STATUS.fetch(agent_status)
    elsif availability_changed?
      self.agent_status = STATUS_BY_AVAILABILITY.fetch(availability)
    end
  end

  def open_agent_status_event
    AgentStatusEvent.create!(account_id: account_id, user_id: user_id, agent_status: agent_status, started_at: Time.current)
  end

  def switch_agent_status_event
    AgentStatusEvent.switch!(self, agent_status, at: agent_status_changed_at || Time.current)
  end

  # Chats that waited through the agent's Ready cool-down are handed out when it ends. Auto-assignment
  # v2 otherwise only runs on a conversation event or its 30-minute sweep.
  def assign_waiting_chats_after_ready_cooldown
    user.inboxes.where(account_id: account_id).find_each do |inbox|
      next unless inbox.enable_auto_assignment? && inbox.auto_assignment_v2_enabled?

      AutoAssignment::AssignmentJob.set(wait: AgentStatusEvent::READY_COOLDOWN).perform_later(inbox_id: inbox.id)
    end
  end

  # Removing the agent ends the open interval, so adding them back can open a new one
  def close_agent_status_event
    AgentStatusEvent.open.where(account_id: account_id, user_id: user_id).update_all(ended_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
