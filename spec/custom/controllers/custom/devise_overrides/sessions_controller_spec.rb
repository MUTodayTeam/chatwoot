require 'rails_helper'

RSpec.describe DeviseOverrides::SessionsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, password: 'Test@123456') }
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:browser_ua) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15' }
  let(:mobile_ua) { 'Dart/3.2 (dart:io)' }

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
    create(:account_user, account: account, user: user)
    create(:account_user, account: other_account, user: user)
  end

  def statuses
    user.account_users.reload.map(&:agent_status)
  end

  describe 'POST #create' do
    it 'starts every membership as busy on a browser sign-in' do
      request.env['HTTP_USER_AGENT'] = browser_ua

      post :create, params: { email: user.email, password: 'Test@123456' }

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('busy'))
    end

    it 'leaves the status alone on a mobile sign-in' do
      request.env['HTTP_USER_AGENT'] = mobile_ua

      post :create, params: { email: user.email, password: 'Test@123456' }

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('ready'))
    end

    it 'starts as busy on an SSO token sign-in from a browser' do
      request.env['HTTP_USER_AGENT'] = browser_ua

      post :create, params: { email: user.email, sso_auth_token: user.generate_sso_auth_token }

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('busy'))
    end

    it 'leaves the status alone on an impersonation sign-in' do
      request.env['HTTP_USER_AGENT'] = browser_ua

      post :create, params: { email: user.email, sso_auth_token: user.generate_sso_auth_token(impersonation: true) }

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('ready'))
    end

    it 'does not change the status on a failed sign-in' do
      request.env['HTTP_USER_AGENT'] = browser_ua

      post :create, params: { email: user.email, password: 'wrong' }

      expect(response).to have_http_status(:unauthorized)
      expect(statuses).to all(eq('ready'))
    end
  end

  describe 'DELETE #destroy' do
    before { request.headers.merge!(user.create_new_auth_token) }

    it 'sets every membership offline on a browser sign-out' do
      request.env['HTTP_USER_AGENT'] = browser_ua

      delete :destroy

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('offline'))
    end

    it 'leaves the status alone on a mobile sign-out' do
      request.env['HTTP_USER_AGENT'] = mobile_ua

      delete :destroy

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('ready'))
    end
  end

  describe 'DELETE #destroy of an impersonation session' do
    it 'leaves the status alone' do
      request.env['HTTP_USER_AGENT'] = browser_ua
      post :create, params: { email: user.email, sso_auth_token: user.generate_sso_auth_token(impersonation: true) }
      request.headers.merge!(response.headers.slice('access-token', 'client', 'uid', 'expiry', 'token-type'))

      delete :destroy

      expect(response).to have_http_status(:success)
      expect(statuses).to all(eq('ready'))
    end
  end
end
