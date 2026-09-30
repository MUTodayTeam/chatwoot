require 'rails_helper'

RSpec.describe 'Contacts filter', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:line_inbox) { create(:inbox, account: account) }
  # Reached only through LINE: no email, phone number or identifier
  let!(:line_contact) { create(:contact, account: account, name: 'Line Guest', email: nil, phone_number: nil, identifier: nil) }
  let(:payload) { [{ attribute_key: 'name', filter_operator: 'contains', values: ['line'] }] }

  before { create(:conversation, account: account, inbox: line_inbox, contact: line_contact) }

  def filtered_ids(user)
    post "/api/v1/accounts/#{account.id}/contacts/filter", params: { payload: payload }, headers: user.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    response.parsed_body['payload'].pluck('id')
  end

  it 'hides a LINE-only contact from an agent outside its inbox' do
    expect(filtered_ids(agent)).to be_empty
  end

  it 'finds a LINE-only contact for an agent of its inbox' do
    create(:inbox_member, inbox: line_inbox, user: agent)

    expect(filtered_ids(agent)).to eq([line_contact.id])
    expect(response.parsed_body['meta']['count']).to eq(1)
  end

  it 'finds a LINE-only contact for an administrator' do
    expect(filtered_ids(admin)).to eq([line_contact.id])
  end

  it 'still leaves out a contact with no email, phone number, identifier or conversation' do
    create(:contact, account: account, name: 'Line Nobody', email: nil, phone_number: nil, identifier: nil)

    expect(filtered_ids(admin)).to eq([line_contact.id])
  end

  context 'with crm_v2 enabled' do
    let!(:lead) { create(:contact, account: account, name: 'Line Lead', email: nil, phone_number: nil, identifier: nil, contact_type: :lead) }

    before do
      account.enable_features!('crm_v2')
      line_contact.update!(email: 'guest@example.com', contact_type: :customer)
    end

    it 'filters leads only, even a customer with a visible conversation' do
      expect(filtered_ids(admin)).to eq([lead.id])
    end
  end
end
