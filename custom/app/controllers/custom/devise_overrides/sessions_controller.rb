# Signing in on the web dashboard starts the agent as Busy (see BusyOnLogin); signing out sets
# Offline. An admin's impersonation session writes no status either way, it is the real agent's.
module Custom::DeviseOverrides::SessionsController
  include Custom::DeviseOverrides::BusyOnLogin

  # Stock writes this flag into an impersonation token when it creates it
  IMPERSONATION_TOKEN_KEY = 'impersonation'.freeze

  # The single exit of every web sign-in: password, SSO token (Google and SAML land here too)
  # and MFA.
  def render_create_success
    start_busy_on_web_login(@resource) unless @impersonation
    super
  end

  def destroy
    # The token is deleted by the time stock yields the user, so read the flag first
    impersonating = @resource&.tokens&.dig(@token.client, IMPERSONATION_TOKEN_KEY)
    super do |user|
      user.account_users.find_each { |account_user| account_user.update!(agent_status: :offline) } if browser_request? && !impersonating
    end
  end
end
