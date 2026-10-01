# Signing in on the web dashboard starts the agent as Busy, so one who only comes in to monitor
# has to pick Ready before receiving chats; signing out sets Offline. The mobile apps are left
# alone (their picker has no Busy-on-login step), and so is an admin's impersonation session.
module Custom::DeviseOverrides::SessionsController
  # The single exit of every web sign-in: password, SSO token (Google and SAML land here too)
  # and MFA.
  def render_create_success
    reset_status_on_login unless @impersonation || !browser_request?
    super
  end

  def destroy
    super do |user|
      user.account_users.find_each { |account_user| account_user.update!(agent_status: :offline) } if browser_request?
    end
  end

  private

  def reset_status_on_login
    @resource.account_users.where.not(agent_status: :busy).find_each { |account_user| account_user.update!(agent_status: :busy) }
  end
end
