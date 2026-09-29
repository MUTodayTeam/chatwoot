module Custom::ActivityMessageHandler
  private

  def create_activity
    super
    create_sweep_flag_activity('missed') if saved_change_to_missed_at?(from: nil)
    create_sweep_flag_activity('expired') if saved_change_to_expired_at?(from: nil)
  end

  def create_sweep_flag_activity(type)
    with_activity_type(type) do
      content = I18n.t("conversations.activity.#{type}", locale: account.locale)
      ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content))
    end
  end

  # A transfer is an assignment with a reason, so it gets one activity that names the reason
  def generate_assignee_change_activity_content(user_name)
    return super if transfer_reason.blank?

    I18n.t('conversations.activity.assignee.transferred', assignee_name: assignee&.name || '', user_name: user_name,
                                                          reason: I18n.t("conversations.activity.transfer_reasons.#{transfer_reason}"))
  end

  # LiveChatRules::SweepJob moves conversations on the clock of the rule it runs for.
  def automation_status_change_activity_content
    rule = Current.executed_by
    return super unless rule.is_a?(LiveChatRule)

    case status
    when 'resolved' then I18n.t('conversations.activity.status.auto_solved', count: rule.auto_solve_hours, locale: account.locale)
    when 'closed' then I18n.t('conversations.activity.status.auto_closed', count: rule.auto_close_hours, locale: account.locale)
    end
  end

  # The conversation timeline tells activities apart by content_attributes.activity,
  # never by their translated text, so the activities it shows carry a type.
  def create_assignee_change_activity(user_name)
    with_activity_type('assignee_changed') { super }
  end

  # Assigning a team, with or without an agent, writes this one activity instead of the assignment's.
  def create_team_change_activity(user_name)
    with_activity_type('team_changed') { super }
  end

  def create_reply_deadline_extended_message(minutes)
    with_activity_type('reply_deadline_extended') { super }
  end

  def activity_message_params(content, content_attributes: nil)
    activity = content_attributes&.dig(:activity) || (@activity_type && { type: @activity_type })
    return super unless activity

    # What the sweep does reads as automatic on the timeline.
    activity = activity.merge(automated: true) if Current.executed_by.is_a?(LiveChatRule)
    super(content, content_attributes: (content_attributes || {}).merge(activity: activity))
  end

  def with_activity_type(type)
    @activity_type = type
    yield
  ensure
    @activity_type = nil
  end
end
