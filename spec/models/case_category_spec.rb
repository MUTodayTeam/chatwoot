require 'rails_helper'

RSpec.describe CaseCategory do
  let(:account) { create(:account) }

  describe 'merge_key' do
    it 'is the trimmed, lowercased path, and the levels are stored trimmed' do
      category = create(:case_category, account: account, c1: ' Booking ', c2: ' Overbooking', c3: 'Same Room  ')

      expect(category.merge_key).to eq('booking|overbooking|same room')
      expect([category.c1, category.c2, category.c3]).to eq(['Booking', 'Overbooking', 'Same Room'])
    end

    it 'trims the no-break, full-width and zero-width spaces pasted text carries' do
      category = create(:case_category, account: account, c1: "\u00A0บัญชี\u3000", c2: "\u200B", c3: "ลืมรหัสผ่าน\u200B\uFEFF")

      expect(category.merge_key).to eq('บัญชี||ลืมรหัสผ่าน')
      expect([category.c1, category.c2, category.c3]).to eq(['บัญชี', '', 'ลืมรหัสผ่าน'])
    end

    it 'keeps Thai text as it is' do
      category = create(:case_category, account: account, c1: 'บัญชีลูกค้า', c2: '', c3: 'ลืมรหัสผ่าน')

      expect(category.merge_key).to eq('บัญชีลูกค้า||ลืมรหัสผ่าน')
    end
  end

  describe 'validations' do
    before { create(:case_category, account: account, c1: 'Booking', c2: 'Overbooking', c3: 'Same room') }

    it 'refuses a second category on the same path whatever its case or spaces' do
      duplicate = build(:case_category, account: account, c1: 'booking ', c2: 'OVERBOOKING', c3: ' same room')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:merge_key]).to be_present
    end

    it 'allows the same path in another account' do
      expect(build(:case_category, c1: 'Booking', c2: 'Overbooking', c3: 'Same room')).to be_valid
    end

    it 'needs Category 1 and Category 3 but not Category 2' do
      expect(build(:case_category, account: account, c1: ' ')).not_to be_valid
      expect(build(:case_category, account: account, c3: nil)).not_to be_valid
      expect(build(:case_category, account: account, c2: nil).tap(&:validate).c2).to eq('')
      expect(build(:case_category, account: account, c2: nil)).to be_valid
    end

    it 'takes a positive SLA or none' do
      expect(build(:case_category, account: account, sla_respond_minutes: 0)).not_to be_valid
      expect(build(:case_category, account: account, sla_respond_minutes: nil, sla_resolve_minutes: nil)).to be_valid
    end

    it 'defaults to Info and rejects an unknown inquiry type' do
      expect(described_class.new.inquiry_type).to eq('info')
      expect(build(:case_category, account: account, inquiry_type: 'complaint')).not_to be_valid
    end
  end

  describe '.search' do
    let!(:booking) { create(:case_category, account: account, c1: 'Booking', c2: 'Overbooking', c3: 'Same room') }
    let!(:member) { create(:case_category, account: account, c1: 'บัญชีลูกค้า', c2: 'สมาชิก', c3: 'สมัครสมาชิก') }

    it 'matches any of the three levels, ignoring case' do
      expect(described_class.search('booking')).to contain_exactly(booking)
      expect(described_class.search('SAME')).to contain_exactly(booking)
      expect(described_class.search('สมาชิก')).to contain_exactly(member)
      expect(described_class.search('%')).to be_empty
    end
  end

  describe 'deleting a category' do
    it 'leaves its cases without one' do
      category = create(:case_category, account: account)
      kase = create(:case, conversation: create(:conversation, account: account), case_category: category)

      category.destroy!

      expect(kase.reload.case_category_id).to be_nil
    end
  end
end
