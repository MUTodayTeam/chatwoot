# Shared by every web login path: a browser sign-in starts the agent as Busy in all their accounts,
# so one who only comes in to monitor has to pick Ready before receiving chats. The mobile apps
# (no Mozilla user agent) are left alone, they have no Busy-on-login step.
module Custom::DeviseOverrides::BusyOnLogin
  private

  def start_busy_on_web_login(user)
    return unless request.user_agent.to_s.include?('Mozilla')

    # as_user names the agent for the audit trail: asking this Devise controller for its current
    # user, which the audit sweeper would do, raises
    Audited.audit_class.as_user(user) do
      user.account_users.where.not(agent_status: :busy).find_each { |account_user| account_user.update!(agent_status: :busy) }
    end
  end
end
