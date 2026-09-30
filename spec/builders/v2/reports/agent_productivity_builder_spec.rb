require 'rails_helper'

RSpec.describe V2::Reports::AgentProductivityBuilder do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:crm) { create(:team, account: account) }
  let(:toon) { create(:user, account: account, role: :agent, name: 'Toon') }
  let(:poy) { create(:user, account: account, role: :agent, name: 'Poy') }
  let(:started_at) { Time.zone.parse('2026-09-15 10:00:00') }
  let(:params) { { since: (started_at - 1.day).to_i.to_s, until: (started_at + 1.day).to_i.to_s } }

  before do
    [toon, poy].each { |member| create(:team_member, team: crm, user: member) }
    account.live_chat_rules.create!(transfer_team: crm)
  end

  after { Current.reset }

  # Toon takes the chat and replies 2 minutes after the customer wrote
  def start_chat(chat_inbox: inbox)
    travel_to(started_at) do
      conversation = create(:conversation, account: account, inbox: chat_inbox, assignee: toon)
      create(:message, account: account, inbox: chat_inbox, conversation: conversation, message_type: :incoming)
      travel(2.minutes)
      create(:message, account: account, inbox: chat_inbox, conversation: conversation, message_type: :outgoing, sender: toon)
      Conversation.find(conversation.id)
    end
  end

  def transfer(conversation, reason, after:)
    travel_to(started_at + after) do
      Current.user = toon
      Conversations::TransferService.new(conversation: Conversation.find(conversation.id), user: toon, assignee_id: poy.id, reason: reason).perform
    end
  end

  def solve(conversation, by:, after:)
    travel_to(started_at + after) do
      Current.user = by
      # The Solved is read from the reporting event its async listener writes
      solve_service = Conversations::SolveService.new(conversation: Conversation.find(conversation.id), user: by, send_survey: false)
      perform_enqueued_jobs { solve_service.perform }
    end
  end

  def agents
    described_class.new(account: account, params: params).build[:agents]
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  def row_for(agent)
    agents.find { |row| row[:id] == agent.id }
  end

  # Spec 10: Toon takes 12 minutes, escalates to Poy, and Poy solves it 8 minutes later
  describe 'the Toon and Poy example' do
    let!(:conversation) { start_chat }

    it 'gives Toon the Assisted and Poy the Resolved' do
      transfer(conversation, 'escalate', after: 12.minutes)
      solve(conversation, by: poy, after: 20.minutes)

      expect(agents.pluck(:name)).to eq(%w[Poy Toon])
      expect(row_for(toon)).to include(
        resolved: 0, assisted: 1, transfer_out: 1, transfer_in: 0, general_transfers: 0, penalty: 0.0,
        contribution_percent: 0.0, avg_handle_time: 12.minutes.to_i, avg_first_response: 2.minutes.to_i, score: 0.5
      )
      expect(row_for(poy)).to include(
        resolved: 1, assisted: 0, transfer_out: 0, transfer_in: 1, general_transfers: 0, penalty: 0.0,
        contribution_percent: 100.0, avg_handle_time: 8.minutes.to_i, avg_first_response: nil, score: 1.0
      )
    end

    it 'costs Toon the transfer penalty for a general handover' do
      transfer(conversation, 'general', after: 12.minutes)
      solve(conversation, by: poy, after: 20.minutes)

      expect(row_for(toon)).to include(assisted: 1, general_transfers: 1, penalty: 0.2, score: 0.3)
    end

    it 'gives Toon the full point when he solves it himself' do
      solve(conversation, by: toon, after: 12.minutes)

      expect(agents).to contain_exactly(include(id: toon.id, resolved: 1, assisted: 0, transfer_out: 0, score: 1.0))
    end

    it 'credits the assignee for a Solved clicked by someone else' do
      admin = create(:user, account: account, role: :administrator)
      solve(conversation, by: admin, after: 12.minutes)

      expect(agents).to contain_exactly(include(id: toon.id, resolved: 1))
    end

    it 'credits the assignee when the rule auto-solves a pending conversation' do
      travel_to(started_at + 12.minutes) { conversation.update!(status: :pending) }
      travel_to(started_at + 12.minutes + 25.hours) { perform_enqueued_jobs { LiveChatRules::SweepJob.perform_now } }
      params[:until] = (started_at + 2.days).to_i.to_s

      expect(conversation.reload).to be_resolved
      expect(agents).to contain_exactly(include(id: toon.id, resolved: 1, score: 1.0))
    end

    it 'takes the weights from the account default rule' do
      account.live_chat_rules.find_by(project_id: nil).update!(assisted_weight: 0.75, transfer_penalty: 0.5)
      transfer(conversation, 'general', after: 12.minutes)
      solve(conversation, by: poy, after: 20.minutes)

      expect(described_class.new(account: account, params: params).build[:weights])
        .to eq(resolved: 1.0, assisted: 0.75, transfer_penalty: 0.5)
      expect(row_for(toon)).to include(penalty: 0.5, score: 0.25)
    end
  end

  it 'counts the conversation by its latest Solved and credits every turn, including those before a reopen' do
    conversation = start_chat
    solve(conversation, by: toon, after: 10.minutes)
    travel_to(started_at + 3.days) do
      Current.user = poy
      Conversations::ReopenService.new(conversation: Conversation.find(conversation.id), user: poy).perform
      Conversations::AssignmentService.new(conversation: Conversation.find(conversation.id), assignee_id: poy.id).perform
    end
    solve(conversation, by: poy, after: 3.days + 10.minutes)

    expect(agents).to be_empty

    params.merge!(since: (started_at + 2.days).to_i.to_s, until: (started_at + 4.days).to_i.to_s)
    expect(agents).to contain_exactly(include(id: poy.id, resolved: 1, assisted: 0), include(id: toon.id, resolved: 0, assisted: 1))
  end

  it 'credits the turns of a conversation solved after it was left unassigned, with no resolver' do
    conversation = start_chat
    travel_to(started_at + 10.minutes) { Conversation.find(conversation.id).update!(assignee: nil) }
    solve(conversation, by: create(:user, account: account, role: :administrator), after: 20.minutes)

    expect(agents).to contain_exactly(include(id: toon.id, resolved: 0, assisted: 1))
  end

  it 'counts a plain reassignment as transfer out and in, but not a reopen turn of the same agent' do
    conversation = start_chat
    travel_to(started_at + 10.minutes) do
      Conversations::AssignmentService.new(conversation: Conversation.find(conversation.id), assignee_id: poy.id).perform
    end
    solve(conversation, by: poy, after: 20.minutes)
    travel_to(started_at + 30.minutes) do
      Current.user = poy
      Conversations::ReopenService.new(conversation: Conversation.find(conversation.id), user: poy).perform
      Conversations::AssignmentService.new(conversation: Conversation.find(conversation.id), assignee_id: poy.id).perform
    end
    solve(conversation, by: poy, after: 40.minutes)

    expect(row_for(toon)).to include(transfer_out: 1, transfer_in: 0, general_transfers: 0)
    expect(row_for(poy)).to include(transfer_out: 0, transfer_in: 1)
  end

  it 'takes the weights from the rule of the selected project, else the account default' do
    project = account.projects.create!(name: 'Checkin+')
    account.live_chat_rules.create!(project: project, assisted_weight: 0.9, transfer_penalty: 0.4)
    default_weights = { resolved: 1.0, assisted: described_class.new(account: account, params: params).build[:weights][:assisted] }

    params[:project_id] = project.id
    expect(described_class.new(account: account, params: params).build[:weights])
      .to eq(resolved: 1.0, assisted: 0.9, transfer_penalty: 0.4)

    params[:project_id] = account.projects.create!(name: 'Other').id
    expect(described_class.new(account: account, params: params).build[:weights]).to include(default_weights)
  end

  it 'leaves out conversations that are open again or solved outside the period' do
    reopened = start_chat
    solve(reopened, by: toon, after: 10.minutes)
    travel_to(started_at + 20.minutes) { Conversation.find(reopened.id).update!(status: :open) }

    later = start_chat
    solve(later, by: toon, after: 2.days)

    expect(agents).to be_empty
  end

  it 'runs the same queries however many conversations and agents there are' do
    solve(start_chat, by: toon, after: 10.minutes)
    queries_for_one = count_queries { agents }

    2.times do
      conversation = start_chat
      transfer(conversation, 'scope', after: 5.minutes)
      solve(conversation, by: poy, after: 10.minutes)
    end

    expect(count_queries { agents }).to eq(queries_for_one)
  end

  it 'filters by project' do
    project = account.projects.create!(name: 'Checkin+')
    solve(start_chat(chat_inbox: create(:inbox, account: account, project: project)), by: toon, after: 10.minutes)
    solve(start_chat, by: poy, after: 10.minutes)

    params[:project_id] = project.id
    expect(agents.pluck(:id)).to eq([toon.id])
  end
end
