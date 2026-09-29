require 'rails_helper'

RSpec.describe 'Cases API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:project) { account.projects.create!(name: 'Checkin+', code: 'CK') }
  let(:team) { create(:team, account: account) }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent) }
  let!(:agent_case) { create(:case, conversation: conversation, project: project, team: team, display_id: 858) }
  let!(:hidden_case) { create(:case, conversation: create(:conversation, account: account, inbox: other_inbox)) }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  describe 'GET /api/v1/accounts/{account.id}/cases' do
    let(:path) { "/api/v1/accounts/#{account.id}/cases" }

    it 'returns unauthorized without a user' do
      get path

      expect(response).to have_http_status(:unauthorized)
    end

    it "lists only the cases of conversations in the agent's inboxes" do
      get path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].pluck('id')).to eq([agent_case.id])
      expect(body['payload'].first).to include(
        'display' => '#CK-858', 'severity' => 'p4', 'status' => 'open', 'reopened_count' => 0,
        'project' => include('code' => 'CK'), 'team' => include('id' => team.id),
        'conversation' => include('id' => conversation.display_id, 'inbox_id' => inbox.id),
        'contact' => include('id' => contact.id), 'owner' => include('id' => agent.id)
      )
      expect(body['meta']).to include('count' => 1, 'open_count' => 1, 'current_page' => 1)
    end

    it 'lists every case to an administrator' do
      get path, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(agent_case.id, hidden_case.id)
    end

    it 'filters by project, team, contact and conversation status' do
      params = { project_id: project.id, team_id: team.id, contact_id: contact.id, status: 'active' }
      get path, params: params, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([agent_case.id])

      get path, params: { status: 'resolved' }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload']).to be_empty
    end

    it "lists a contact's cases on their own for Contact 360" do
      get path, params: { contact_id: hidden_case.conversation.contact_id }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([hidden_case.id])
    end

    it 'counts the cases of the selected project only' do
      create(:case, conversation: create(:conversation, account: account, inbox: other_inbox, status: :resolved))

      get path, params: { project_id: project.id }, headers: admin.create_new_auth_token

      expect(response.parsed_body['meta']).to include('count' => 1, 'open_count' => 1)
    end

    it "gives the conversation's status clock for the auto-close countdown" do
      conversation.resolved!
      legacy = hidden_case.conversation
      legacy.update_columns(status_changed_at: nil, updated_at: 3.hours.ago) # rubocop:disable Rails/SkipsModelValidations

      get path, headers: admin.create_new_auth_token

      clocks = response.parsed_body['payload'].to_h { |kase| [kase['id'], kase['conversation']['status_changed_at']] }
      expect(clocks).to eq(agent_case.id => conversation.reload.status_changed_at.to_i, hidden_case.id => legacy.reload.updated_at.to_i)
    end

    it 'counts the open cases apart from the Solved and Closed ones' do
      hidden_case.conversation.resolved!

      get path, headers: admin.create_new_auth_token

      expect(response.parsed_body['meta']).to include('count' => 2, 'open_count' => 1)
    end

    it 'lists as mine the cases I own and the ones whose conversation I replied in' do
      replied = create(:case, conversation: create(:conversation, account: account, inbox: other_inbox))
      create(:message, account: account, conversation: replied.conversation, sender: admin, message_type: :outgoing)
      noted = create(:case, conversation: create(:conversation, account: account, inbox: other_inbox))
      create(:message, account: account, conversation: noted.conversation, sender: admin, message_type: :outgoing, private: true)
      conversation.update!(assignee: admin)

      get path, params: { mine: true }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(agent_case.id, replied.id)
    end

    it 'pages the list' do
      get path, params: { page: 2 }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload']).to be_empty
      expect(response.parsed_body['meta']).to include('count' => 2, 'current_page' => 2)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/cases/{id}' do
    it 'shows a case the agent can see' do
      get "/api/v1/accounts/#{account.id}/cases/#{agent_case.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['display']).to eq('#CK-858')
      expect(response.parsed_body).to include('category' => nil, 'summary' => nil, 'resolved_by' => nil)
    end

    it 'shows the category, summary and solver of a solved case' do
      category = create(:case_category, account: account, inquiry_type: :problem, c1: 'Booking', c2: 'Overbooking', c3: 'Same room')
      agent_case.update!(case_category: category, summary: 'Moved to another room', resolved_by: agent)

      get "/api/v1/accounts/#{account.id}/cases/#{agent_case.id}", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to include(
        'category' => include('id' => category.id, 'inquiry_type' => 'problem', 'c1' => 'Booking', 'c2' => 'Overbooking', 'c3' => 'Same room'),
        'summary' => 'Moved to another room',
        'resolved_by' => { 'id' => agent.id, 'name' => agent.available_name }
      )
    end

    it 'refuses a case outside the agent inboxes' do
      get "/api/v1/accounts/#{account.id}/cases/#{hidden_case.id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not find a case of another account' do
      foreign = create(:case)

      get "/api/v1/accounts/#{account.id}/cases/#{foreign.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/cases/{id}' do
    let(:path) { "/api/v1/accounts/#{account.id}/cases/#{agent_case.id}" }
    let(:other_team) { create(:team, account: account) }

    it 'updates the subject, severity and team only' do
      patch path, params: { subject: 'Refund', severity: 'p1', team_id: other_team.id, reopened_count: 5, display_id: 1 },
                  headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(agent_case.reload).to have_attributes(subject: 'Refund', severity: 'p1', team_id: other_team.id, reopened_count: 0,
                                                   display_id: 858)
    end

    it 'rejects an unknown severity and a team of another account' do
      patch path, params: { severity: 'p9' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch path, params: { team_id: create(:team).id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a missing subject and a team that does not exist' do
      patch path, params: { subject: nil }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch path, params: { team_id: 0 }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(agent_case.reload).to have_attributes(subject: 'Cannot check in', team_id: team.id)
    end

    it 'refuses a case outside the agent inboxes' do
      patch "/api/v1/accounts/#{account.id}/cases/#{hidden_case.id}", params: { subject: 'x' },
                                                                      headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(hidden_case.reload.subject).not_to eq('x')
    end
  end

  describe 'the conversation payload' do
    it 'carries the case number, severity and category' do
      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['case']).to eq('id' => agent_case.id, 'display' => '#CK-858', 'severity' => 'p4', 'case_category_id' => nil)
    end

    it 'is pushed with conversation events' do
      expect(conversation.push_event_data[:case]).to eq(id: agent_case.id, display: '#CK-858', severity: 'p4', case_category_id: nil)
    end
  end
end
