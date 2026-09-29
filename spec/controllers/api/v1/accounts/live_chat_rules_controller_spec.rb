require 'rails_helper'

RSpec.describe 'Live chat rules API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:lifecycle_params) do
    { waiting_time_minutes: 15, auto_solve_hours: 12, auto_close_hours: 36, transfer_team_id: team.id,
      assisted_weight: 0.25, transfer_penalty: 0.1, chat_limit: 3 }
  end

  describe 'POST /api/v1/accounts/{account.id}/live_chat_rules' do
    it 'saves and returns the lifecycle settings' do
      post "/api/v1/accounts/#{account.id}/live_chat_rules",
           params: { reply_timeout_minutes: 30, extension_minutes: 10, **lifecycle_params },
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(lifecycle_params.stringify_keys)
      expect(account.live_chat_rules.last).to have_attributes(auto_solve_hours: 12, auto_close_hours: 36, transfer_team_id: team.id)
    end

    it 'falls back to the column defaults' do
      post "/api/v1/accounts/#{account.id}/live_chat_rules", params: { reply_timeout_minutes: 30 }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('waiting_time_minutes' => 60, 'auto_solve_hours' => 24, 'auto_close_hours' => 48,
                                              'chat_limit' => 10, 'transfer_team_id' => nil, 'assisted_weight' => 0.5, 'transfer_penalty' => 0.2)
    end

    it 'rejects a transfer team from another account' do
      post "/api/v1/accounts/#{account.id}/live_chat_rules",
           params: { transfer_team_id: create(:team).id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.live_chat_rules).to be_empty
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/live_chat_rules/{id}' do
    let!(:rule) { account.live_chat_rules.create! }

    it 'updates the lifecycle settings' do
      patch "/api/v1/accounts/#{account.id}/live_chat_rules/#{rule.id}",
            params: lifecycle_params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(rule.reload).to have_attributes(waiting_time_minutes: 15, auto_solve_hours: 12, auto_close_hours: 36,
                                             assisted_weight: 0.25, transfer_penalty: 0.1)
    end

    it 'rejects hours that are not positive' do
      patch "/api/v1/accounts/#{account.id}/live_chat_rules/#{rule.id}",
            params: { auto_solve_hours: 0 }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(rule.reload.auto_solve_hours).to eq(24)
    end

    it 'does not let an agent change them' do
      patch "/api/v1/accounts/#{account.id}/live_chat_rules/#{rule.id}",
            params: lifecycle_params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(rule.reload.auto_solve_hours).to eq(24)
    end
  end
end
