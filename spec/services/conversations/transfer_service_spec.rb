require 'rails_helper'

RSpec.describe Conversations::TransferService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:project) { account.projects.create!(name: 'Checkin+') }
  let(:inbox) { create(:inbox, account: account, project: project) }
  let(:crm) { create(:team, account: account, name: 'CRM') }
  let(:toon) { create(:user, account: account, role: :agent, name: 'Toon') }
  let(:poy) { create(:user, account: account, role: :agent, name: 'Poy') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: toon) }
  let(:handlers) { conversation.handlers.order(:started_at, :id) }

  # Loaded afresh like a request does: a just-created conversation has display_id pending from its trigger
  def transfer(assignee: poy, reason: 'escalate', note: nil)
    described_class.new(conversation: Conversation.find(conversation.id), user: toon, assignee_id: assignee.id, reason: reason, note: note).perform
  end

  def refusal_of(&)
    yield
  rescue CustomExceptions::ConversationActionRefused => e
    e.message
  end

  before do
    Current.user = toon
    [toon, poy].each { |member| create(:team_member, team: crm, user: member) }
  end

  after { Current.reset }

  context 'with the transfer team on the account default rule' do
    before { account.live_chat_rules.create!(transfer_team: crm) }

    it 'ends the outgoing turn with the reason and the note, then opens the incoming one' do
      travel_to(12.minutes.from_now) { transfer(note: 'ลูกค้าขอคุยกับหัวหน้า') }

      expect(conversation.reload.assignee).to eq(poy)
      expect(handlers.map { |handler| [handler.user_id, handler.end_reason, handler.ended_by_id, handler.note] })
        .to eq([[toon.id, 'escalate', toon.id, 'ลูกค้าขอคุยกับหัวหน้า'], [poy.id, nil, nil, nil]])
    end

    it 'leaves the note as a private note and writes one activity that names the reason' do
      transfer(reason: 'shift', note: 'Refund is approved, just confirm the bank')
      perform_enqueued_jobs

      note = conversation.messages.where(private: true).last
      expect(note).to have_attributes(content: 'Refund is approved, just confirm the bank', sender: toon, message_type: 'outgoing')
      expect(conversation.messages.activity.pluck(:content))
        .to include('Transferred to Poy by Toon · End of shift or on leave')
      expect(conversation.messages.activity.pluck(:content)).not_to include('Assigned to Poy by Toon')
    end

    it 'refuses a reason that is not a transfer reason' do
      expect(refusal_of { transfer(reason: 'solved') }).to eq('Pick a reason for the transfer')
      expect(conversation.reload.assignee).to eq(toon)
    end

    it 'refuses someone outside the transfer team, the user themselves and the current assignee' do
      outsider = create(:user, account: account, role: :agent)
      conversation.update!(assignee: poy)

      [outsider, toon, poy].each do |assignee|
        expect(refusal_of { transfer(assignee: assignee) })
          .to eq('Pick a member of the transfer team other than yourself and the current assignee')
      end
      expect(handlers.open.pluck(:user_id)).to eq([poy.id])
    end

    it 'refuses a Solved conversation' do
      conversation.update!(status: :resolved)

      expect(refusal_of { transfer }).to eq('A solved or closed conversation cannot be transferred')
      expect(conversation.reload.assignee).to eq(toon)
    end

    it 'lists the team without the user and the current assignee' do
      lead = create(:user, account: account, role: :agent, name: 'Aom')
      create(:team_member, team: crm, user: lead)

      expect(described_class.candidates(conversation, toon)).to eq([lead, poy])
    end
  end

  it "uses the project's transfer team over the account default" do
    other_team = create(:team, account: account)
    create(:team_member, team: other_team, user: poy)
    account.live_chat_rules.create!(transfer_team: other_team)
    account.live_chat_rules.create!(project: project, transfer_team: crm)

    expect(described_class.transfer_team(conversation)).to eq(crm)
  end

  it 'falls back to the account default when the project rule leaves the team unset' do
    account.live_chat_rules.create!(transfer_team: crm)
    account.live_chat_rules.create!(project: project)

    expect(described_class.transfer_team(conversation)).to eq(crm)
  end

  it 'refuses when no transfer team is set up' do
    account.live_chat_rules.create!

    expect(refusal_of { transfer }).to eq('No transfer team is set up in the live chat rules for this project')
  end
end
