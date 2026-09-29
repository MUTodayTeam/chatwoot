module Custom::ActivityMessageHandler
  private

  def automation_status_change_activity_content
    return super unless Current.executed_by.is_a?(LiveChatRule)

    I18n.t("conversations.activity.status.#{status}", user_name: I18n.t('automation.system_name'), locale: account.locale)
  end
end
