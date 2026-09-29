require 'rails_helper'

RSpec.describe Agents::DestroyJob do
  let(:account) { create(:account) }
  let(:removed) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account, assignee: removed) }
  let!(:other_conversation) { create(:conversation, account: account, assignee: colleague) }

  it "ends the removed agent's turns as unassigned and leaves everyone else's open" do
    described_class.perform_now(account, removed)

    expect(conversation.handlers.pluck(:user_id, :end_reason)).to eq([[removed.id, 'unassigned']])
    expect(conversation.handlers.open).to be_empty
    expect(other_conversation.handlers.open.pluck(:user_id)).to eq([colleague.id])
  end
end
