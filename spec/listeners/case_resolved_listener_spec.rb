require 'rails_helper'

describe CaseResolvedListener do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }
  let(:solved_activity) { 'Solved · Other · closes automatically in 48 hours' }

  after { Current.reset }

  it 'runs on the sync dispatcher, so a resolve knows who resolved it' do
    expect(SyncDispatcher.new.listeners.map { |sync| sync.class.name }).to include(described_class.name)
    expect(AsyncDispatcher.new.listeners.map { |async| async.class.name }).not_to include(described_class.name)
  end

  it 'records who resolved it from toggle_status and says when it closes' do
    Current.user = admin

    expect { conversation.update!(status: :resolved) }
      .to have_enqueued_job(Conversations::ActivityMessageJob).with(conversation, hash_including(content: solved_activity))
    expect(conversation.reload.case.resolved_by).to eq(admin)
  end

  it 'records the agent who ran bulk Solved' do
    BulkActionsJob.perform_now(account: account, user: admin,
                               params: { type: 'Conversation', fields: { status: 'resolved' }, ids: [conversation.display_id] })

    expect(conversation.reload.case.resolved_by).to eq(admin)
  end

  it 'records the assignee when the auto-solve sweep resolves it' do
    conversation.update!(status: :pending)
    conversation.update_columns(status_changed_at: 25.hours.ago) # rubocop:disable Rails/SkipsModelValidations

    LiveChatRules::SweepJob.perform_now

    expect(conversation.reload).to be_resolved
    expect(conversation.case.resolved_by).to eq(agent)
  end

  it 'opens the case, with no team or resolver, for a conversation nobody took' do
    unassigned = create(:conversation, account: account, status: :pending)
    unassigned.update_columns(status_changed_at: 25.hours.ago) # rubocop:disable Rails/SkipsModelValidations

    expect { LiveChatRules::SweepJob.perform_now }
      .to have_enqueued_job(Conversations::ActivityMessageJob).with(unassigned, hash_including(content: solved_activity))
    expect(unassigned.reload.case).to have_attributes(team_id: nil, resolved_by_id: nil)
  end

  it 'keeps the case an agent already took' do
    kase = create(:case, conversation: conversation)
    Current.user = agent

    conversation.update!(status: :resolved)

    expect(Case.where(conversation: conversation).sole).to have_attributes(id: kase.id, resolved_by_id: agent.id)
  end
end
