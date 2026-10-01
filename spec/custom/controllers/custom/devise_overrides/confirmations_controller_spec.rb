require 'rails_helper'

RSpec.describe DeviseOverrides::ConfirmationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:account) { create(:account) }

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
    create(:account_user, account: account, user: user)
    user.update_columns(confirmed_at: nil, confirmation_token: 'confirm-token') # rubocop:disable Rails/SkipsModelValidations
  end

  it 'starts the agent as busy when a browser confirms the email' do
    request.env['HTTP_USER_AGENT'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15'

    post :create, params: { confirmation_token: 'confirm-token' }

    expect(response).to have_http_status(:success)
    expect(user.account_users.reload.map(&:agent_status)).to all(eq('busy'))
  end

  it 'leaves the status alone when a non-browser client confirms the email' do
    request.env['HTTP_USER_AGENT'] = 'Dart/3.2 (dart:io)'

    post :create, params: { confirmation_token: 'confirm-token' }

    expect(response).to have_http_status(:success)
    expect(user.account_users.reload.map(&:agent_status)).to all(eq('ready'))
  end
end
