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
      create(:contact, :with_email, account: account, name: 'Somchai', additional_attributes: { company_name: 'Nadol Resort' },
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

    it 'answers an empty search like stock' do
      get "/api/v1/accounts/#{account.id}/contacts/search", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['payload']).to be_empty
    end
  end

  context 'with a LINE-only contact whose chat is in an inbox the agent is not a member of' do
    let(:agent) { create(:user, account: account, role: :agent) }
    let!(:line_only) do
      create(:contact, account: account, name: 'Jane Tester', email: nil, phone_number: nil, identifier: nil,
                       additional_attributes: { company_name: 'Sample Resort' }, custom_attributes: { partner_id: 'ZZ-0001' })
    end

    before do
      create(:inbox_member, inbox: project_inbox, user: agent)
      create(:conversation, account: account, inbox: other_inbox, contact: line_only)
    end

    %w[jane sample zz-0001].each do |query|
      it "keeps it out of the search for #{query}" do
        get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: query }, headers: agent.create_new_auth_token

        expect(response.parsed_body['payload'].pluck('id')).not_to include(line_only.id)
      end
    end

    it 'finds it once the agent joins the inbox' do
      create(:inbox_member, inbox: other_inbox, user: agent)

      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'sample' }, headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([line_only.id])
    end
  end

  context 'with crm_v2 enabled' do
    let(:agent) { create(:user, account: account, role: :agent) }
    let!(:lead) { create(:contact, account: account, name: 'Lead Tester', email: nil, phone_number: nil, identifier: nil, contact_type: :lead) }
    let!(:customer) { create(:contact, :with_email, account: account, name: 'Lead Customer', contact_type: :customer) }

    before do
      account.enable_features!('crm_v2')
      create(:inbox_member, inbox: project_inbox, user: agent)
      create(:conversation, account: account, inbox: project_inbox, contact: customer)
    end

    it 'lists leads only, even a customer with a visible conversation' do
      get "/api/v1/accounts/#{account.id}/contacts", headers: admin.create_new_auth_token

      ids = response.parsed_body['payload'].pluck('id')
      expect(ids).to include(lead.id)
      expect(ids).not_to include(customer.id)
    end

    it 'searches leads only for an agent' do
      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'lead' }, headers: agent.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to eq([lead.id])
    end

    it 'searches every contact for an administrator, like stock' do
      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'lead' }, headers: admin.create_new_auth_token

      expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(lead.id, customer.id)
    end
  end

  it 'finds for an administrator a name-only contact with no conversation, like stock' do
    name_only = create(:contact, account: account, name: 'Nameonly Person', email: nil, phone_number: nil, identifier: nil)

    get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'nameonly' }, headers: admin.create_new_auth_token

    expect(response.parsed_body['payload'].pluck('id')).to eq([name_only.id])
  end

  context 'with a custom role that only manages the chats it takes part in', if: ChatwootApp.enterprise? do
    let(:agent) { create(:user, account: account, role: :agent) }
    let!(:line_only) { create(:contact, account: account, name: 'Jane Tester', email: nil, phone_number: nil, identifier: nil) }

    before do
      create(:inbox_member, inbox: project_inbox, user: agent)
      create(:conversation, account: account, inbox: project_inbox, contact: line_only, assignee: admin)
      role = create(:custom_role, account: account, permissions: ['conversation_participating_manage'])
      AccountUser.find_by(account: account, user: agent).update!(custom_role: role)
    end

    it 'hides a contact whose only chat belongs to someone else from the list and the search' do
      get "/api/v1/accounts/#{account.id}/contacts", headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('id')).not_to include(line_only.id)

      get "/api/v1/accounts/#{account.id}/contacts/search", params: { q: 'jane' }, headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('id')).not_to include(line_only.id)
    end
  end
end
