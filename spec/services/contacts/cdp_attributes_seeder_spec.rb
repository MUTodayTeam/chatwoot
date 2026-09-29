require 'rails_helper'

RSpec.describe Contacts::CdpAttributesSeeder do
  let(:account) { create(:account) }

  it 'keeps what an admin has edited when it runs again' do
    described_class.new(account).perform
    type = account.custom_attribute_definitions.find_by!(attribute_key: 'contact_type')
    type.update!(attribute_display_name: 'ประเภท', attribute_values: ['Partner โรงแรม'])

    expect { described_class.new(account).perform }.not_to change(CustomAttributeDefinition, :count)
    expect(type.reload).to have_attributes(attribute_display_name: 'ประเภท', attribute_values: ['Partner โรงแรม'])
  end

  it 'leaves a conversation attribute with the same key alone' do
    create(:custom_attribute_definition, account: account, attribute_key: 'partner_id', attribute_model: :conversation_attribute)

    described_class.new(account).perform

    expect(account.custom_attribute_definitions.where(attribute_key: 'partner_id').pluck(:attribute_model))
      .to contain_exactly('conversation_attribute', 'contact_attribute')
  end
end
