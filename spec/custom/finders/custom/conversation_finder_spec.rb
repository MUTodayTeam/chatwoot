require 'rails_helper'

RSpec.describe Custom::ConversationFinder do
  subject(:result) { ConversationFinder.new(admin, params).perform }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  before { Current.account = account }

  after { Current.account = nil }

  context 'with status=active' do
    let(:params) { { status: 'active' } }

    it 'returns every conversation still being worked on' do
      active = %i[open pending snoozed].map { |status| create(:conversation, account: account, inbox: inbox, status: status) }
      create(:conversation, account: account, inbox: inbox, status: :resolved)
      create(:conversation, account: account, inbox: inbox, status: :resolved).tap(&:closed!)

      expect(result[:conversations].map(&:id)).to match_array(active.map(&:id))
    end
  end

  context 'with status=missed' do
    let(:params) { { status: 'missed' } }

    it 'returns the missed conversations in any status and counts only those' do
      missed = %i[open resolved].map { |status| create(:conversation, account: account, inbox: inbox, status: status, missed_at: 1.hour.ago) }
      create(:conversation, account: account, inbox: inbox, status: :open)

      expect(result[:conversations].map(&:id)).to match_array(missed.map(&:id))
      expect(result[:count][:all_count]).to eq(2)
    end
  end
end
