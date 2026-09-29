require 'rails_helper'

RSpec.describe 'Conversation Transfer API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:crm) { create(:team, account: account) }
  let(:toon) { create(:user, account: account, role: :agent, name: 'Toon') }
  let(:poy) { create(:user, account: account, role: :agent, name: 'Poy') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: toon) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transfer" }

  before do
    create(:inbox_member, inbox: inbox, user: toon)
    [toon, poy].each { |member| create(:team_member, team: crm, user: member) }
    account.live_chat_rules.create!(transfer_team: crm)
  end

  describe 'GET transfer' do
    it 'returns unauthorized without a user' do
      get path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'is refused to an agent who cannot see the conversation' do
      get path, headers: create(:user, account: account, role: :agent).create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the transfer team without the caller, and the open turn' do
      get path, headers: toon.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['team']).to eq('id' => crm.id, 'name' => crm.name)
      expect(body['agents'].pluck('id')).to eq([poy.id])
      expect(body['handler']).to include('user_id' => toon.id, 'started_at' => conversation.handlers.open.first.started_at.to_i)
    end
  end

  describe 'POST transfer' do
    it 'returns unauthorized without a user' do
      post path, params: { assignee_id: poy.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'is refused to an agent who cannot see the conversation' do
      post path, params: { assignee_id: poy.id }, headers: create(:user, account: account, role: :agent).create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(conversation.reload.assignee).to eq(toon)
    end

    it 'hands the conversation over, out of scope by default' do
      post path, params: { assignee_id: poy.id }, headers: toon.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('conversation_id' => conversation.display_id, 'assignee' => include('id' => poy.id))
      expect(conversation.reload.assignee).to eq(poy)
      expect(conversation.handlers.where(user: toon).pick(:end_reason)).to eq('scope')
    end

    it 'returns 422 for an assignee outside the transfer team' do
      outsider = create(:user, account: account, role: :agent)

      post path, params: { assignee_id: outsider.id, reason: 'general' }, headers: toon.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('Pick a member of the transfer team other than yourself and the current assignee')
      expect(conversation.reload.assignee).to eq(toon)
    end

    it 'returns 422 when no transfer team is configured' do
      account.live_chat_rules.update_all(transfer_team_id: nil) # rubocop:disable Rails/SkipsModelValidations

      post path, params: { assignee_id: poy.id }, headers: toon.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq('No transfer team is set up in the live chat rules for this project')
    end

    it 'returns 422 without an assignee' do
      post path, params: { reason: 'scope' }, headers: toon.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
