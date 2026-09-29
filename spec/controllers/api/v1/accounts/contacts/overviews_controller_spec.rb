require 'rails_helper'

RSpec.describe 'Contact overview API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { account.projects.create!(name: 'Checkin+', code: 'CK') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/contacts/#{contact.id}/overview" }

  let!(:solved) do
    create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent, created_at: 3.days.ago).tap do |conversation|
      create(:case, conversation: conversation, project: project, display_id: 858, subject: 'Cannot check in')
      conversation.resolved!
    end
  end
  let!(:closed) do
    create(:conversation, account: account, inbox: other_inbox, contact: contact, created_at: 2.days.ago, missed_at: 2.days.ago).tap do |conversation|
      create(:message, conversation: conversation, message_type: :incoming, content: 'Where is my booking?')
      conversation.resolved!
      conversation.closed!
    end
  end
  let!(:latest) { create(:conversation, account: account, inbox: inbox, contact: contact, created_at: 1.day.ago) }

  before do
    create(:conversation, account: account, inbox: inbox)
    create(:inbox_member, inbox: inbox, user: agent)
  end

  it 'returns unauthorized without a user' do
    get path

    expect(response).to have_http_status(:unauthorized)
  end

  it 'counts every conversation of the contact and lists the Solved and Closed ones, newest first' do
    get path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body).to include(
      'conversations_count' => 3,
      'first_contact_at' => solved.created_at.to_i,
      'latest_conversation' => { 'id' => latest.display_id, 'status' => 'open' }
    )
    expect(body['history'].pluck('id')).to eq([closed.display_id, solved.display_id])
    expect(body['history'].first).to include(
      'status' => 'closed', 'topic' => 'Where is my booking?', 'case' => nil, 'project' => nil,
      'channel' => other_inbox.channel_type, 'agent' => nil, 'bot' => false, 'missed' => true
    )
    expect(body['history'].last).to include(
      'status' => 'resolved', 'topic' => 'Cannot check in', 'case' => include('display' => '#CK-858'),
      'project' => include('id' => project.id, 'code' => 'CK'), 'agent' => { 'id' => agent.id, 'name' => agent.available_name },
      'missed' => false
    )
  end

  it 'credits whoever solved the case over the assignee' do
    solver = create(:user, account: account, role: :administrator)
    solved.case.update!(resolved_by: solver)

    get path, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['history'].last['agent']).to eq('id' => solver.id, 'name' => solver.available_name)
  end

  it 'keeps the six most recent' do
    stub_const('Api::V1::Accounts::Contacts::OverviewsController::HISTORY_LIMIT', 1)

    get path, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['history'].pluck('id')).to eq([closed.display_id])
  end

  it "shows an agent only the conversations in the agent's inboxes" do
    get path, headers: agent.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['conversations_count']).to eq(2)
    expect(body['history'].pluck('id')).to eq([solved.display_id])
  end

  it 'returns an empty overview for a contact with no conversation' do
    get "/api/v1/accounts/#{account.id}/contacts/#{create(:contact, account: account).id}/overview",
        headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to eq(
      'conversations_count' => 0, 'first_contact_at' => nil, 'latest_conversation' => nil, 'history' => []
    )
  end
end
