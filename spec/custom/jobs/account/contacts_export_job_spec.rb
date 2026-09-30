require 'rails_helper'

RSpec.describe Account::ContactsExportJob do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:line_inbox) { create(:inbox, account: account) }
  let(:line_contact) { create(:contact, account: account, name: 'Line Guest', email: nil, phone_number: nil, identifier: nil) }
  let(:filter) { { payload: [{ attribute_key: 'name', filter_operator: 'contains', values: ['line'] }] }.with_indifferent_access }

  before do
    create(:conversation, account: account, inbox: line_inbox, contact: line_contact)
    create(:contact, account: account, name: 'Line Nobody', email: nil, phone_number: nil, identifier: nil)
    create(:contact, :with_email, account: account, name: 'Line Mailer')
  end

  def exported_names(user, params = filter)
    described_class.perform_now(account.id, user.id, %w[id name], params)
    CSV.parse(account.contacts_export.download.force_encoding('UTF-8').delete_prefix("\xEF\xBB\xBF"), headers: true).pluck('name')
  end

  it 'exports the filtered list the administrator sees, LINE-only contacts included' do
    expect(exported_names(admin)).to contain_exactly('Line Guest', 'Line Mailer')
  end

  it 'never exports a LINE-only contact the user could not list' do
    agent = create(:user, account: account, role: :agent)

    expect(exported_names(agent)).to contain_exactly('Line Mailer')
  end

  it 'exports what the Contacts list shows when no filter is given' do
    expect(exported_names(admin, {})).to contain_exactly('Line Guest', 'Line Mailer')
  end

  it 'exports the LINE-only contacts carrying the label' do
    line_contact.update!(label_list: ['vip'])

    expect(exported_names(admin, { label: 'vip' }.with_indifferent_access)).to contain_exactly('Line Guest')
  end

  it 'leaves a LINE-only contact out of an unfiltered export by an agent who cannot see it' do
    agent = create(:user, account: account, role: :agent)

    expect(exported_names(agent, {})).to contain_exactly('Line Mailer')
  end
end
