require 'rails_helper'

RSpec.describe Custom::SearchService do
  subject(:conversations) do
    SearchService.new(current_user: agent, current_account: account, params: { q: query }, search_type: 'Conversation').perform[:conversations]
  end

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hotel_contact) do
    create(:contact, account: account, name: 'Somchai', additional_attributes: { company_name: 'Nadol Resort' },
                     custom_attributes: { partner_id: 'CK-4471' })
  end
  let!(:hotel_conversation) { create(:conversation, account: account, inbox: inbox, contact: hotel_contact, status: :open) }

  before do
    Current.account = account
    create(:inbox_member, user: agent, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: create(:contact, account: account, name: 'Other guest'))
  end

  after { Current.account = nil }

  context 'when the query is part of the hotel name' do
    let(:query) { 'nadol' }

    it 'finds the conversation by the contact company name' do
      expect(conversations.map(&:id)).to eq([hotel_conversation.id])
    end

    it 'includes solved and closed conversations' do
      closed = create(:conversation, account: account, inbox: inbox, contact: hotel_contact, status: :resolved).tap(&:closed!)
      solved = create(:conversation, account: account, inbox: inbox, contact: hotel_contact, status: :resolved)

      expect(conversations.map(&:id)).to contain_exactly(hotel_conversation.id, closed.id, solved.id)
    end
  end

  context 'when the query is the Partner ID' do
    let(:query) { 'ck-4471' }

    it 'finds the conversation by the partner_id custom attribute' do
      expect(conversations.map(&:id)).to eq([hotel_conversation.id])
    end
  end

  context 'when the hotel is in an inbox the agent cannot see' do
    let(:query) { 'nadol' }

    it 'keeps the inbox restriction' do
      create(:conversation, account: account, inbox: create(:inbox, account: account), contact: hotel_contact)

      expect(conversations.map(&:id)).to eq([hotel_conversation.id])
    end
  end

  context 'when the query matches the contact name' do
    let(:query) { 'somchai' }

    it 'keeps the stock contact matching' do
      expect(conversations.map(&:id)).to eq([hotel_conversation.id])
    end
  end
end
