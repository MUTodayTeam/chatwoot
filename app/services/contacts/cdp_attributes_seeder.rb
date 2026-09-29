# Type and Partner ID are contact custom attributes, not columns. Seeding only creates what is
# missing, so running it again keeps any label or option an admin has since edited.
class Contacts::CdpAttributesSeeder
  TYPE_KEY = 'contact_type'.freeze
  PARTNER_ID_KEY = 'partner_id'.freeze
  TYPES = ['Partner โรงแรม', 'ลูกค้าลอตเตอรี่', 'MUToday member'].freeze
  DEFINITIONS = {
    TYPE_KEY => { attribute_display_name: 'Type', attribute_display_type: :list, attribute_values: TYPES },
    PARTNER_ID_KEY => { attribute_display_name: 'Partner ID', attribute_display_type: :text }
  }.freeze

  def initialize(account)
    @account = account
  end

  def perform
    DEFINITIONS.each do |key, definition|
      @account.custom_attribute_definitions.contact_attribute.find_or_create_by!(attribute_key: key) do |record|
        record.assign_attributes(definition)
      end
    end
  end
end
