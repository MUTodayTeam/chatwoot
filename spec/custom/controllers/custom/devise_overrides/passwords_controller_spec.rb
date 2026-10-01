require 'rails_helper'

RSpec.describe DeviseOverrides::PasswordsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:reset_token) { user.send_reset_password_instructions }
  let(:params) { { reset_password_token: reset_token, password: 'Test@123456', password_confirmation: 'Test@123456' } }

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
    create(:account_user, account: account, user: user)
  end

  it 'starts the agent as busy when a browser resets the password' do
    request.env['HTTP_USER_AGENT'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15'

    put :update, params: params

    expect(response).to have_http_status(:success)
    expect(user.account_users.reload.map(&:agent_status)).to all(eq('busy'))
  end

  it 'leaves the status alone when a non-browser client resets the password' do
    request.env['HTTP_USER_AGENT'] = 'Dart/3.2 (dart:io)'

    put :update, params: params

    expect(response).to have_http_status(:success)
    expect(user.account_users.reload.map(&:agent_status)).to all(eq('ready'))
  end
end
