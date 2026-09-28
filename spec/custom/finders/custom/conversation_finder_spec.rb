require 'rails_helper'

RSpec.describe Custom::ConversationFinder do
  subject(:result) { ConversationFinder.new(admin, { status: 'active' }).perform }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  before { Current.account = account }

  after { Current.account = nil }

  it 'returns every conversation still being worked on for status=active' do
    active = %i[open pending snoozed].map { |status| create(:conversation, account: account, inbox: inbox, status: status) }
    create(:conversation, account: account, inbox: inbox, status: :resolved)
    create(:conversation, account: account, inbox: inbox, status: :resolved).tap(&:closed!)

    expect(result[:conversations].map(&:id)).to match_array(active.map(&:id))
  end
end
