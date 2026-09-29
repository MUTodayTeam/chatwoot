require 'rails_helper'

RSpec.describe 'Contacts filtered by project', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:project) { account.projects.create!(name: 'Checkin+') }
  let(:project_inbox) { create(:inbox, account: account, project: project) }
  let(:other_inbox) { create(:inbox, account: account) }
  let(:hotel) { create(:contact, :with_email, account: account, name: 'Hotel Siam') }
  let(:guest) { create(:contact, :with_email, account: account, name: 'Hotel guest') }

  before do
    # Two conversations in the project still list the contact once
    create_list(:conversation, 2, account: account, inbox: project_inbox, contact: hotel)
    create(:conversation, account: account, inbox: other_inbox, contact: guest)
  end

  it 'lists each contact with a conversation in the project once' do
    get "/api/v1/accounts/#{account.id}/contacts", params: { project_id: project.id }, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['payload'].pluck('id')).to eq([hotel.id])
    expect(response.parsed_body['meta']['count']).to eq(1)
  end

  it 'combines with the label filter' do
    hotel.update!(label_list: ['vip'])
    guest.update!(label_list: ['vip'])

    get "/api/v1/accounts/#{account.id}/contacts", params: { project_id: project.id, labels: ['vip'] }, headers: admin.create_new_auth_token

    expect(response.parsed_body['payload'].pluck('id')).to eq([hotel.id])
  end

  it 'narrows the search the same way' do
    get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'Hotel', project_id: project.id }, headers: admin.create_new_auth_token

    expect(response.parsed_body['payload'].pluck('id')).to eq([hotel.id])
  end

  it 'lists every contact without a project' do
    get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'Hotel' }, headers: admin.create_new_auth_token

    expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(hotel.id, guest.id)
  end

  it "lists for an agent only the contacts whose project conversation is in the agent's inboxes" do
    agent = create(:user, account: account, role: :agent)

    get "/api/v1/accounts/#{account.id}/contacts", params: { project_id: project.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body['payload']).to be_empty

    create(:inbox_member, inbox: project_inbox, user: agent)
    get "/api/v1/accounts/#{account.id}/contacts", params: { project_id: project.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body['payload'].pluck('id')).to eq([hotel.id])
  end

  it "ignores another account's project" do
    other_project = create(:account).projects.create!(name: 'Elsewhere')

    get "/api/v1/accounts/#{account.id}/contacts", params: { project_id: other_project.id }, headers: admin.create_new_auth_token

    expect(response.parsed_body['payload']).to be_empty
  end

  context 'with a contact that only has a LINE-style source id' do
    let(:line_only) { create(:contact, account: account, name: 'Jane Tester', email: nil, phone_number: nil, identifier: nil) }

    before { create(:conversation, account: account, inbox: project_inbox, contact: line_only) }

    it 'lists it for an administrator' do
      get "/api/v1/accounts/#{account.id}/contacts", headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to include(line_only.id)
    end

    it 'keeps the label filter applied' do
      get "/api/v1/accounts/#{account.id}/contacts", params: { labels: ['vip'] }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to be_empty
    end

    it 'hides it from an agent who cannot see its conversation' do
      agent = create(:user, account: account, role: :agent)

      get "/api/v1/accounts/#{account.id}/contacts", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).not_to include(line_only.id)
    end

    it 'lists it for an agent in the inbox' do
      agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: project_inbox, user: agent)

      get "/api/v1/accounts/#{account.id}/contacts", headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to include(line_only.id)
    end
  end

  context 'when searching by hotel' do
    let!(:partner) do
      create(:contact, account: account, name: 'Somchai', additional_attributes: { company_name: 'Nadol Resort' },
                       custom_attributes: { partner_id: 'CK-4471' })
    end

    it 'finds the contact by company name' do
      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'nadol' }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([partner.id])
    end

    it 'finds the contact by Partner ID' do
      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'ck-4471' }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([partner.id])
    end

    it 'still asks for a search string' do
      get "/api/v1/accounts/#{account.id}/contacts/search", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
