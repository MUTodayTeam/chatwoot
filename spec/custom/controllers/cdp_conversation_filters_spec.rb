require 'rails_helper'

RSpec.describe 'CDP conversation filters and search', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hotel) { create(:contact, account: account, name: 'Somchai', additional_attributes: { company_name: 'Nadol Resort' }) }
  let!(:missed) { create(:conversation, account: account, inbox: inbox, contact: hotel, status: :resolved, missed_at: 2.hours.ago) }
  let!(:answered) { create(:conversation, account: account, inbox: inbox, status: :open) }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'GET /api/v1/accounts/{account.id}/conversations with status=missed' do
    it 'lists the missed conversations and flags them in the payload' do
      get "/api/v1/accounts/#{account.id}/conversations", params: { status: 'missed', assignee_type: 'all' },
                                                          headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body['data']
      expect(body['payload'].pluck('id')).to eq([missed.display_id])
      expect(body['payload'].first['missed_at']).to eq(missed.missed_at.to_i)
      expect(body['meta']['all_count']).to eq(1)
    end

    it 'counts the missed conversations for the tabs' do
      get "/api/v1/accounts/#{account.id}/conversations/meta", params: { status: 'missed' }, headers: agent.create_new_auth_token

      expect(response.parsed_body['meta']).to include('all_count' => 1, 'unassigned_count' => 1)
    end

    it 'reports 0 for a conversation that was never missed' do
      get "/api/v1/accounts/#{account.id}/conversations", params: { status: 'open', assignee_type: 'all' },
                                                          headers: agent.create_new_auth_token

      expect(response.parsed_body['data']['payload'].first).to include('id' => answered.display_id, 'missed_at' => 0)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/search/conversations' do
    it "finds a solved conversation by the contact's hotel" do
      get "/api/v1/accounts/#{account.id}/search/conversations", params: { q: 'Nadol' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload']['conversations'].pluck('id')).to eq([missed.display_id])
    end
  end
end
