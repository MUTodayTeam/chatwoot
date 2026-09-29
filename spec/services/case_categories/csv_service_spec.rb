require 'rails_helper'

RSpec.describe CaseCategories::CsvService do
  let(:headers) { ['Category 1', 'Category 2', 'Category 3', 'SLA (ตอบภายใน / ปิดภายใน)', 'Inquiry Type'] }

  describe '.template' do
    it 'is a UTF-8 BOM and the A to E headers' do
      template = described_class.template

      expect(template).to start_with("\uFEFF")
      expect(CSV.parse(template.delete_prefix("\uFEFF"))).to eq([headers])
    end
  end

  describe '.export' do
    let(:account) { create(:account) }

    it 'writes every category in the columns the import reads back' do
      create(:case_category, account: account, inquiry_type: :problem, c1: 'โรงแรม / Partner', c2: 'การจอง', c3: 'Overbooking',
                             sla_respond_minutes: 15, sla_resolve_minutes: 240)
      create(:case_category, account: account, inquiry_type: :info, c1: 'ทั่วไป', c2: '', c3: 'Greeting',
                             sla_respond_minutes: 5, sla_resolve_minutes: nil)
      create(:case_category, account: account, c1: 'บัญชีลูกค้า', c3: 'ลืมรหัสผ่าน', sla_respond_minutes: nil, sla_resolve_minutes: nil)

      csv = described_class.export(CaseCategory.where(account_id: account.id).order(:id))

      expect(csv).to start_with("\uFEFF")
      expect(CSV.parse(csv.delete_prefix("\uFEFF"))).to eq(
        [
          headers,
          ['โรงแรม / Partner', 'การจอง', 'Overbooking', '15 นาที / 4 ชม.', 'Problem'],
          ['ทั่วไป', '', 'Greeting', '5 นาที / —', 'Info'],
          ['บัญชีลูกค้า', 'สถานะคำสั่งซื้อ', 'ลืมรหัสผ่าน', '', 'Request']
        ]
      )
    end

    it 'round-trips through the import as all skipped' do
      create(:case_category, account: account, sla_respond_minutes: 90, sla_resolve_minutes: 2880)
      csv = described_class.export(CaseCategory.where(account_id: account.id))

      result = CaseCategories::ImportService.new(account: account, content: csv).perform

      expect(result).to include(added: [], skipped: 1, invalid: [])
    end
  end
end
