require 'rails_helper'

RSpec.describe 'Conversation Solve API', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, csat_survey_enabled: true) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let(:category) { create(:case_category, account: account, c1: 'คำสั่งซื้อ', c2: 'สถานะคำสั่งซื้อ', c3: 'ติดตามสถานะคำสั่งซื้อ') }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/solve" }
  let(:csat_messages) { conversation.messages.where(content_type: :input_csat) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'สถานะคำสั่งซื้อ')
  end

  it 'returns unauthorized without a user' do
    post path

    expect(response).to have_http_status(:unauthorized)
  end

  it 'is refused to an agent who cannot see the conversation' do
    outsider = create(:user, account: account, role: :agent)

    post path, params: { case_category_id: category.id }, headers: outsider.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(conversation.reload).to be_open
  end

  it 'resolves the conversation and files its case under the category, solved by the agent' do
    post path, params: { case_category_id: category.id, summary: 'แจ้งเลขพัสดุแล้ว', send_survey: true },
               headers: agent.create_new_auth_token, as: :json
    # Jobs run after the request: run inline, the first one would reset Current.user before
    # the resolve's own activity is written
    perform_enqueued_jobs

    expect(response).to have_http_status(:success)
    expect(conversation.reload).to be_resolved
    kase = conversation.case
    expect(kase).to have_attributes(case_category: category, resolved_by: agent, summary: 'แจ้งเลขพัสดุแล้ว')
    expect(response.parsed_body).to include(
      'current_status' => 'resolved', 'case' => include('id' => kase.id, 'case_category_id' => category.id)
    )
    # The stock resolve ran: CSAT went out and the resolution was reported
    expect(csat_messages.count).to eq(1)
    expect(ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_resolved')).to exist
  end

  it "tells the timeline the topic and when the rule's auto close will close it" do
    account.live_chat_rules.create!(auto_close_hours: 72)

    post path, params: { case_category_id: category.id }, headers: agent.create_new_auth_token, as: :json
    perform_enqueued_jobs

    contents = conversation.messages.activity.pluck(:content)
    expect(contents).to include('Solved · ติดตามสถานะคำสั่งซื้อ · closes automatically in 72 hours')
    expect(contents).to include("Conversation was marked resolved by #{agent.name}")
  end

  it 'files the case as Other without a category' do
    post path, headers: agent.create_new_auth_token, as: :json
    perform_enqueued_jobs

    expect(conversation.reload.case).to have_attributes(case_category_id: nil, resolved_by: agent)
    expect(conversation.messages.activity.pluck(:content)).to include('Solved · Other · closes automatically in 48 hours')
  end

  it 'opens the case of a conversation nobody took before solving it' do
    conversation.update!(assignee: nil)

    post path, params: { case_category_id: category.id }, headers: agent.create_new_auth_token, as: :json

    expect(conversation.reload.case).to have_attributes(case_category: category, resolved_by: agent, subject: 'สถานะคำสั่งซื้อ')
  end

  it 'skips the CSAT survey for this resolve only when send_survey is false' do
    post path, params: { case_category_id: category.id, send_survey: false }, headers: agent.create_new_auth_token, as: :json
    perform_enqueued_jobs

    expect(conversation.reload).to be_resolved
    expect(csat_messages).to be_empty

    perform_enqueued_jobs do
      conversation.open!
      conversation.resolved!
    end

    expect(csat_messages.count).to eq(1)
  end

  it 'keeps the survey for a later resolve when the customer reopened before the listener ran' do
    post path, params: { send_survey: false }, headers: agent.create_new_auth_token, as: :json
    conversation.reload.open!
    perform_enqueued_jobs

    perform_enqueued_jobs { conversation.reload.resolved! }

    expect(csat_messages.count).to eq(1)
  end

  it 'refuses a conversation that is already solved' do
    conversation.resolved!

    post path, params: { case_category_id: category.id }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Case.find_by(conversation_id: conversation.id)&.case_category_id).to be_nil
  end

  it "refuses another account's category" do
    post path, params: { case_category_id: create(:case_category).id }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
    expect(conversation.reload).to be_open
  end
end
