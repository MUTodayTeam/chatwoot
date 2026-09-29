require 'rails_helper'

# Closed only goes back to open, so a bulk change that includes a closed conversation
# leaves that one as it is and still updates the rest of the selection.
RSpec.describe BulkActionsJob do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:open_conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let!(:closed_conversation) { create(:conversation, account: account, inbox: inbox).tap(&:resolved!).tap(&:closed!) }
  let(:ids) { [open_conversation.display_id, closed_conversation.display_id] }

  before { create(:inbox_member, inbox: inbox, user: agent) }

  after { Current.reset }

  def perform(fields, snoozed_until: nil)
    described_class.perform_now(
      account: account,
      user: agent,
      params: { type: 'Conversation', ids: ids, fields: fields, snoozed_until: snoozed_until }.compact
    )
  end

  it 'resolves the rest and leaves the closed conversation closed' do
    perform({ status: 'resolved' })

    expect(open_conversation.reload).to be_resolved
    expect(closed_conversation.reload).to be_closed
  end

  it 'snoozes the rest and leaves the closed conversation closed' do
    perform({ status: 'snoozed' }, snoozed_until: 1.day.from_now.to_i.to_s)

    expect(open_conversation.reload).to be_snoozed
    expect(closed_conversation.reload).to be_closed
    expect(closed_conversation.snoozed_until).to be_nil
  end

  it 'reopens a closed conversation' do
    perform({ status: 'open' })

    expect(closed_conversation.reload).to be_open
  end
end
