require 'rails_helper'

RSpec.describe CaseCategories::ImportService do
  subject(:result) { described_class.new(account: account, content: content).perform }

  let(:account) { create(:account) }
  let(:header) { "Category 1,Category 2,Category 3,SLA (ตอบภายใน / ปิดภายใน),Inquiry Type\n" }
  let!(:existing) do
    create(:case_category, account: account, c1: 'คำสั่งซื้อ', c2: 'สถานะคำสั่งซื้อ', c3: 'ติดตามสถานะคำสั่งซื้อ',
                           sla_respond_minutes: 30, sla_resolve_minutes: 60)
  end

  context 'with a file exported by Excel as CSV UTF-8' do
    let(:content) do
      "\uFEFF#{header}" \
        "คำสั่งซื้อ,สถานะคำสั่งซื้อ,ติดตามสถานะคำสั่งซื้อ,15 นาที / 1 วัน,Request\n" \
        "โรงแรม / Partner,การจอง,Overbooking · จองซ้ำห้องเดียวกัน,15 นาที / 4 ชม.,Problem\n" \
        "ทั่วไป,ทักทาย,Greeting,5 นาที / —,info\n" \
        "บัญชีลูกค้า,ความปลอดภัย,ลืมรหัสผ่าน / ปลดล็อกบัญชี,,\n" \
        ",,\n" \
        "ทั่วไป,,,5 นาที,Info\n" \
        ",ทักทาย,Greeting,,\n"
    end

    it 'adds the new categories with their Thai text and SLA' do
      expect(result[:added].map(&:c3)).to eq(['Overbooking · จองซ้ำห้องเดียวกัน', 'Greeting', 'ลืมรหัสผ่าน / ปลดล็อกบัญชี'])
      overbooking, greeting, password = result[:added]
      expect(overbooking).to have_attributes(c1: 'โรงแรม / Partner', inquiry_type: 'problem', sla_respond_minutes: 15, sla_resolve_minutes: 240)
      expect(greeting).to have_attributes(inquiry_type: 'info', sla_respond_minutes: 5, sla_resolve_minutes: nil)
      # Inquiry Type is optional and defaults to Request (spec 15)
      expect(password).to have_attributes(inquiry_type: 'request', sla_respond_minutes: nil, sla_resolve_minutes: nil)
      expect(CaseCategory.where(account_id: account.id).count).to eq(4)
    end

    it 'strips the BOM so the header row is recognised and not imported' do
      expect(CaseCategory.where(c1: 'Category 1')).not_to exist
      expect(result[:invalid].pluck(:line)).not_to include(1)
    end

    it 'skips a path that already exists and leaves its SLA alone' do
      expect(result[:skipped]).to eq(1)
      expect(existing.reload).to have_attributes(sla_respond_minutes: 30, sla_resolve_minutes: 60)
    end

    it 'reports the rows without Category 1 or Category 3 as invalid, by spreadsheet line' do
      expect(result[:invalid]).to eq(
        [
          { line: 7, values: ['ทั่วไป', '', '', '5 นาที', 'Info'], reason: :missing_category },
          { line: 8, values: ['', 'ทักทาย', 'Greeting', '', ''], reason: :missing_category }
        ]
      )
    end
  end

  context 'with the same path twice in one file, in different case' do
    let(:content) { "Booking,Overbooking,Same room,,\n booking , OVERBOOKING,same room,15,Problem\n" }

    it 'adds the first and skips the second' do
      expect(result[:added].map(&:c3)).to eq(['Same room'])
      expect(result[:skipped]).to eq(1)
    end
  end

  context 'with a file that has no header row' do
    let(:content) { "Booking,Overbooking,Same room,1 d / 2 days,problem\n" }

    it 'imports the first row too, reading English units' do
      expect(result[:added].first).to have_attributes(c3: 'Same room', sla_respond_minutes: 1440, sla_resolve_minutes: 2880)
    end
  end

  context 'with an SLA or inquiry type it cannot read' do
    let(:content) { "Booking,Overbooking,Same room,soon,\nBooking,Overbooking,Late check-out,15,Complaint\n" }

    it 'reports them as invalid and adds nothing' do
      expect(result[:invalid].pluck(:line, :reason)).to eq([[1, :invalid_sla], [2, :invalid_inquiry_type]])
      expect(result[:added]).to be_empty
    end
  end

  context 'with a file Excel saved as plain CSV on a Thai system' do
    let(:content) { "ทั่วไป,ทักทาย,อวยพร,5 นาที,Info\n".encode('Windows-874').b }

    it 'reads it as Windows-874' do
      expect(result[:added].first).to have_attributes(c1: 'ทั่วไป', c2: 'ทักทาย', c3: 'อวยพร', sla_respond_minutes: 5)
    end
  end

  context 'with malformed CSV' do
    let(:content) { "Booking,\"Overbooking,Same room\n" }

    it 'raises for the controller to report' do
      expect { result }.to raise_error(CSV::MalformedCSVError)
    end
  end
end
