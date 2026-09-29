module Custom::ActivityMessageHandler
  private

  # LiveChatRules::SweepJob moves conversations on the clock of the rule it runs for.
  def automation_status_change_activity_content
    rule = Current.executed_by
    return super unless rule.is_a?(LiveChatRule)

    case status
    when 'resolved' then I18n.t('conversations.activity.status.auto_solved', count: rule.auto_solve_hours, locale: account.locale)
    when 'closed' then I18n.t('conversations.activity.status.auto_closed', count: rule.auto_close_hours, locale: account.locale)
    end
  end
end
