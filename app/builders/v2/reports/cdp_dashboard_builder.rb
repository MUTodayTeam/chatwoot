class V2::Reports::CdpDashboardBuilder
  include DateRangeHelper
  include TimezoneHelper

  DEFAULT_AGENT_CONVERSATION_LIMIT = 10
  ACTIVE_CONVERSATION_STATUSES = %w[open pending snoozed].freeze
  # Anything from 20:00 to 06:59 counts as outside business hours.
  BUSINESS_HOURS = (7..19)
  CHANNEL_KEYS = { 'Channel::Line' => :line, 'Channel::FacebookPage' => :facebook }.freeze

  # A conversation starts at its first incoming message, so one whose first incoming
  # message came before the period is left out even if the customer wrote again inside it.
  STARTED_CONVERSATIONS_SQL = <<~SQL.squish.freeze
    SELECT messages.conversation_id, MIN(messages.created_at) AS started_at
    FROM messages
    WHERE messages.account_id = :account_id
      AND messages.message_type = :incoming
      AND messages.inbox_id IN (:inbox_ids)
      AND messages.created_at >= :since AND messages.created_at < :until
      AND NOT EXISTS (
        SELECT 1 FROM messages earlier
        WHERE earlier.conversation_id = messages.conversation_id
          AND earlier.account_id = messages.account_id
          AND earlier.message_type = :incoming
          AND earlier.created_at < :since
      )
    GROUP BY messages.conversation_id
  SQL

  FIRST_AGENT_REPLY_SQL = <<~SQL.squish.freeze
    LEFT JOIN LATERAL (
      SELECT MIN(replies.created_at) AS replied_at
      FROM messages replies
      WHERE replies.conversation_id = started.conversation_id
        AND replies.account_id = :account_id
        AND replies.message_type = :outgoing
        AND replies.sender_type = 'User'
        AND replies.private = FALSE
        AND replies.created_at >= started.started_at
    ) first_reply ON TRUE
  SQL

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    { period: period, kpis: kpis, daily_channels: daily_channels, interval_summary: interval_summary, interval_heatmap: interval_heatmap,
      agent_load: agent_load }
  end

  private

  def period
    { since: range.begin.to_i, until: range.end.to_i, previous_since: previous_range.begin.to_i, previous_until: previous_range.end.to_i }
  end

  def previous_range
    @previous_range ||= (range.begin - (range.end - range.begin))...range.begin
  end

  def kpis
    current = period_metrics(range)
    previous = period_metrics(previous_range)

    current.to_h do |key, value|
      [key, { current: value, previous: previous[key], delta_percent: delta_percent(value, previous[key]) }]
    end
  end

  def period_metrics(period_range)
    total_chats, missed_chats, expired_chats, first_response_time = started_chat_stats(period_range)
    # Outgoing counts only agent (User) messages; bot, automation and Captain replies are left out.
    messages = account.messages.unscope(:order).where(inbox_id: inbox_ids, created_at: period_range, private: false)
    message_counts = messages.where(message_type: :incoming).or(messages.where(message_type: :outgoing, sender_type: 'User'))
                             .group(:message_type).count

    {
      total_chats: total_chats,
      incoming_messages: message_counts['incoming'] || 0,
      outgoing_messages: message_counts['outgoing'] || 0,
      missed_chats: missed_chats,
      expired_chats: expired_chats,
      first_response_time: first_response_time&.round
    }
  end

  # AVG skips conversations without an agent reply, so they count as chats but not towards first response.
  # Missed and expired are flags the sweep sets whenever it happens, so a chat that started in the
  # period counts once flagged, even if that came after the period ended.
  def started_chat_stats(period_range)
    started_conversations(period_range)
      .joins(sanitize(FIRST_AGENT_REPLY_SQL, outgoing: Message.message_types[:outgoing]))
      .pick(Arel.sql('COUNT(*)'), Arel.sql('COUNT(conversations.missed_at)'), Arel.sql('COUNT(conversations.expired_at)'),
            Arel.sql('AVG(EXTRACT(EPOCH FROM first_reply.replied_at - started.started_at))'))
  end

  def delta_percent(current, previous)
    return if current.nil? || previous.nil? || previous.zero?

    ((current - previous) * 100.0 / previous).round(1)
  end

  def daily_channels
    days.map do |day|
      counts = daily_counts.fetch(day, {})
      { date: day.strftime('%Y-%m-%d'), line: counts[:line] || 0, facebook: counts[:facebook] || 0, others: counts[:others] || 0,
        total: counts.values.sum }
    end
  end

  # { date => { line: n, facebook: n, others: n } }
  def daily_counts
    @daily_counts ||= started_conversations(range)
                      .joins(:inbox)
                      .group('inboxes.channel_type')
                      .group_by_period(:day, 'started.started_at', time_zone: timezone)
                      .count
                      .each_with_object(Hash.new { |hash, day| hash[day] = Hash.new(0) }) do |((channel_type, day), count), result|
                        result[day][CHANNEL_KEYS.fetch(channel_type, :others)] += count
                      end
  end

  def interval_summary
    hourly = started_conversations(range).group_by_hour_of_day('started.started_at', time_zone: timezone).count
    total = hourly.values.sum
    return { total: 0, peak_hour: nil, busiest_day: nil, busiest_weekday: nil, outside_business_hours: nil } if total.zero?

    {
      total: total,
      peak_hour: peak_hour(hourly),
      busiest_day: busiest_day,
      busiest_weekday: busiest_weekday,
      outside_business_hours: outside_business_hours(hourly, total)
    }
  end

  # Every hour of the period, empty ones included, in the shape of the V2 reports API's hourly series.
  def interval_heatmap
    started_conversations(range).group_by_period(:hour, 'started.started_at', time_zone: timezone, range: range).count
                                .map { |hour, count| { timestamp: hour.to_i, value: count } }
  end

  def peak_hour(hourly)
    hour, count = hourly.max_by { |entry_hour, entry_count| [entry_count, -entry_hour] }
    { hour: hour, count: count }
  end

  def day_totals
    @day_totals ||= days.index_with { |day| daily_counts.fetch(day, {}).values.sum }
  end

  def busiest_day
    day, count = day_totals.max_by { |entry_day, entry_count| [entry_count, -entry_day.jd] }
    { date: day.strftime('%Y-%m-%d'), count: count }
  end

  # Days without chats count towards the average, so a weekday is not favoured just for appearing once.
  def busiest_weekday
    averages = day_totals.group_by { |day, _count| day.wday }.transform_values { |entries| entries.sum(&:last).fdiv(entries.size) }
    weekday, average = averages.max_by { |entry_weekday, entry_average| [entry_average, -entry_weekday] }
    { weekday: weekday, average: average.round(1) }
  end

  def outside_business_hours(hourly, total)
    count = hourly.sum { |hour, hour_count| BUSINESS_HOURS.cover?(hour) ? 0 : hour_count }
    { count: count, percent: (count * 100.0 / total).round(1) }
  end

  def agent_load
    agents = account.users.where(id: InboxMember.where(inbox_id: inbox_ids).select(:user_id)).pluck(:id, :name)
    inbox_limits = agent_inbox_limits(agents.map(&:first))

    rows = agents.map do |id, name|
      limits = inbox_limits[id]
      # An agent with per-inbox caps is measured only on the capped inboxes, against the sum of those caps.
      next { id: id, name: name, assigned_count: assigned_count(id, inbox_ids), limit: DEFAULT_AGENT_CONVERSATION_LIMIT } unless limits

      { id: id, name: name, assigned_count: assigned_count(id, limits.keys), limit: limits.values.sum }
    end
    rows.sort_by { |row| [-row[:assigned_count], row[:name]] }
  end

  def assigned_count(agent_id, counted_inbox_ids)
    @active_counts ||= account.conversations.where(inbox_id: inbox_ids, status: ACTIVE_CONVERSATION_STATUSES).group(:assignee_id, :inbox_id).count
    @active_counts.sum { |(assignee_id, inbox_id), count| assignee_id == agent_id && counted_inbox_ids.include?(inbox_id) ? count : 0 }
  end

  # { user_id => { inbox_id => limit } } for agents capped per inbox; Enterprise reads advanced assignment capacity policies.
  def agent_inbox_limits(_user_ids)
    {}
  end

  def started_conversations(period_range)
    started_sql = sanitize(STARTED_CONVERSATIONS_SQL, incoming: Message.message_types[:incoming], inbox_ids: inbox_ids,
                                                      since: period_range.begin, until: period_range.end)
    account.conversations.joins("INNER JOIN (#{started_sql}) started ON started.conversation_id = conversations.id")
  end

  def sanitize(sql, values)
    ActiveRecord::Base.sanitize_sql_array([sql, values.merge(account_id: account.id)])
  end

  def inbox_ids
    @inbox_ids ||= begin
      inboxes = params[:project_id].present? ? account.projects.find(params[:project_id]).inboxes : account.inboxes
      inboxes.pluck(:id)
    end
  end

  def days
    @days ||= begin
      first_day = range.begin.in_time_zone(timezone).to_date
      last_day = (range.end - 1.second).in_time_zone(timezone).to_date
      (first_day..last_day).to_a
    end
  end

  def timezone
    @timezone ||= timezone_name_from_offset(params[:timezone_offset])
  end
end

V2::Reports::CdpDashboardBuilder.prepend_mod_with('V2::Reports::CdpDashboardBuilder')
