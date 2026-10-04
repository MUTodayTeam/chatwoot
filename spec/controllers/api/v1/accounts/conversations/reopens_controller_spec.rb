require 'rails_helper'

RSpec.describe 'Conversation Reopen API', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:toon) { create(:user, account: account, role: :agent, name: 'Toon') }
  let(:poy) { create(:user, account: account, role: :agent, name: 'Poy') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: toon) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/reopen" }

  before do
    [toon, poy].each { |member| create(:inbox_member, inbox: inbox, user: member) }
    create(:case, conversation: conversation)
    conversation.update!(status: :resolved)
  end

  it 'returns unauthorized without a user' do
    post path

    expect(response).to have_http_status(:unauthorized)
  end

  it 'is refused to an agent who cannot see the conversation' do
    post path, headers: create(:user, account: account, role: :agent).create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(conversation.reload).to be_resolved
  end

  it 'reopens to the previous agent with a new turn, and counts the reopen once' do
    perform_enqueued_jobs(only: EventDispatcherJob) do
      post path, headers: poy.create_new_auth_token, as: :json
    end

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('current_status' => 'open', 'assignee_id' => toon.id)
    expect(conversation.reload).to be_open
    expect(conversation.handlers.order(:started_at, :id).pluck(:user_id, :end_reason)).to eq([[toon.id, 'solved'], [toon.id, nil]])
    expect(conversation.case.reopened_count).to eq(1)
  end

  it 'gives a Closed conversation without an agent to the agent reopening it' do
    conversation.update!(assignee: nil, status: :closed)

    post path, headers: poy.create_new_auth_token, as: :json

    expect(conversation.reload).to have_attributes(status: 'open', assignee: poy)
    expect(conversation.handlers.open.pluck(:user_id)).to eq([poy.id])
  end

  it 'reopens a conversation without an agent but does not give it to a developer' do
    conversation.update!(assignee: nil)
    account.account_users.find_by(user: poy).update!(developer: true)

    post path, headers: poy.create_new_auth_token, as: :json

    expect(conversation.reload).to have_attributes(status: 'open', assignee: nil)
    expect(conversation.handlers.open).to be_empty
  end

  it 'returns 422 for a conversation that is not Solved or Closed' do
    conversation.update!(status: :open)

    post path, headers: toon.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to eq('Only a solved or closed conversation can be reopened')
  end
end
