require 'rake'
require 'rails_helper'

RSpec.describe Rake::Task do
  subject(:task) { described_class['cdp:seed_contact_attributes'] }

  let!(:account) { create(:account) }
  let!(:other_account) { create(:account) }

  before { task.reenable }

  def definitions(for_account)
    for_account.custom_attribute_definitions.contact_attribute.order(:attribute_key)
  end

  it 'creates Type and Partner ID once however often it runs' do
    with_modified_env ACCOUNT_ID: account.id.to_s do
      2.times do
        task.reenable
        task.invoke
      end
    end

    expect(definitions(account).pluck(:attribute_key, :attribute_display_type, :attribute_values)).to eq(
      [
        ['contact_type', 'list', ['Partner โรงแรม', 'ลูกค้าลอตเตอรี่', 'MUToday member']],
        ['partner_id', 'text', []]
      ]
    )
    expect(definitions(other_account)).to be_empty
  end

  it 'seeds every account when no ACCOUNT_ID is given' do
    with_modified_env ACCOUNT_ID: nil do
      task.invoke
    end

    expect(definitions(account).count).to eq(2)
    expect(definitions(other_account).count).to eq(2)
  end
end
