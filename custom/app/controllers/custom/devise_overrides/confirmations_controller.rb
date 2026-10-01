# Confirming an email signs the agent in on the web, so it starts them as Busy like any login.
module Custom::DeviseOverrides::ConfirmationsController
  include Custom::DeviseOverrides::BusyOnLogin

  def send_auth_headers(user)
    start_busy_on_web_login(user)
    super
  end
end
