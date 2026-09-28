require 'rails_helper'

RSpec.describe V2::Reports::CdpDashboardBuilder do
  let!(:account) { create(:account) }
  let!(:project) { Project.create!(account: account, name: 'Share') }
  let!(:line_inbox) { create(:inbox, account: account, project: project, channel: create(:channel_line, account: account, inbox: nil)) }
  # Lazy, so the Facebook page subscription is stubbed before the channel is created.
  let(:facebook_inbox) { create(:inbox, account: account, project: project, channel: create(:channel_facebook_page, account: account)) }
  let!(:widget_inbox) { create(:inbox, account: account, project: project) }
  let!(:alice) { create(:user, account: account, name: 'Alice') }
  let!(:bob) { create(:user, account: account, name: 'Bob') }

  # Current period: 13-19 Sep 2026 (UTC); previous period: 6-12 Sep 2026.
  let(:params) do
    { since: Time.utc(2026, 9, 13).to_i.to_s, until: Time.utc(2026, 9, 20).to_i.to_s, timezone_offset: '0', project_id: project.id }
  end
  let(:report) { described_class.new(account: account, params: params).build }

  # Conversation A (LINE): starts Mon 14 Sep 10:00, agent reply 10 minutes later.
  let!(:line_conversation) { create(:conversation, account: account, inbox: line_inbox, assignee: alice, status: :open) }
  # Conversation C (web widget): starts Mon 14 Sep 18:30, only a bot replies.
  let!(:widget_conversation) { create(:conversation, account: account, inbox: widget_inbox, assignee: alice, status: :pending) }
  # Conversation E (LINE): starts Thu 17 Sep 10:30, nobody replies.
  let!(:unanswered_conversation) { create(:conversation, account: account, inbox: line_inbox, assignee: alice) }
  # Conversation B (Facebook): starts in the previous period, customer writes again in the current one.
  let(:facebook_conversation) { create(:conversation, account: account, inbox: facebook_inbox, assignee: bob, status: :snoozed) }

  before do
    stub_request(:post, /graph.facebook.com/)
    # Conversation D: an inbox outside the project, with its own agent.
    outside_inbox = create(:inbox, account: account)
    carol = create(:user, account: account, name: 'Carol')
    outside_conversation = create(:conversation, account: account, inbox: outside_inbox, assignee: carol, status: :open)

    create(:inbox_member, user: alice, inbox: line_inbox)
    create(:inbox_member, user: bob, inbox: facebook_inbox)
    create(:inbox_member, user: carol, inbox: outside_inbox)

    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 14, 10))
    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :outgoing,
                     sender: create(:agent_bot, account: account), created_at: Time.utc(2026, 9, 14, 10, 1))
    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :outgoing, sender: alice,
                     private: true, created_at: Time.utc(2026, 9, 14, 10, 5))
    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :outgoing, sender: alice,
                     created_at: Time.utc(2026, 9, 14, 10, 10))
    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 14, 10, 12))
    create(:message, account: account, inbox: line_inbox, conversation: line_conversation, message_type: :activity,
                     created_at: Time.utc(2026, 9, 14, 10, 13))

    create(:message, account: account, inbox: widget_inbox, conversation: widget_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 14, 18, 30))
    create(:message, :bot_message, account: account, inbox: widget_inbox, conversation: widget_conversation,
                                   created_at: Time.utc(2026, 9, 14, 18, 31))

    create(:message, account: account, inbox: line_inbox, conversation: unanswered_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 17, 10, 30))

    create(:message, account: account, inbox: facebook_inbox, conversation: facebook_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 8, 9))
    create(:message, account: account, inbox: facebook_inbox, conversation: facebook_conversation, message_type: :outgoing, sender: bob,
                     created_at: Time.utc(2026, 9, 8, 9, 20))
    create(:message, account: account, inbox: facebook_inbox, conversation: facebook_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 15, 9))

    create(:message, account: account, inbox: outside_inbox, conversation: outside_conversation, message_type: :incoming,
                     created_at: Time.utc(2026, 9, 16, 12))

    # Resolved after its messages, since an incoming message reopens a resolved conversation.
    unanswered_conversation.update!(status: :resolved)
  end

  describe 'period' do
    it 'compares against the period of the same length right before it' do
      expect(report[:period]).to eq(
        since: Time.utc(2026, 9, 13).to_i, until: Time.utc(2026, 9, 20).to_i,
        previous_since: Time.utc(2026, 9, 6).to_i, previous_until: Time.utc(2026, 9, 13).to_i
      )
    end
  end

  describe 'kpis' do
    it 'counts conversations whose first incoming message is in the period' do
      expect(report[:kpis][:total_chats]).to eq(current: 3, previous: 1, delta_percent: 200.0)
    end

    it 'counts customer and agent messages without private notes, activity or bot messages' do
      expect(report[:kpis][:incoming_messages]).to eq(current: 5, previous: 1, delta_percent: 400.0)
      expect(report[:kpis][:outgoing_messages]).to eq(current: 1, previous: 1, delta_percent: 0.0)
    end

    it 'averages the first agent reply over conversations that have one' do
      expect(report[:kpis][:first_response_time]).to eq(current: 600, previous: 1200, delta_percent: -50.0)
    end

    it 'leaves the delta empty when the previous period has nothing to compare against' do
      params[:since] = Time.utc(2026, 9, 6).to_i.to_s
      params[:until] = Time.utc(2026, 9, 13).to_i.to_s

      expect(report[:kpis][:total_chats]).to eq(current: 1, previous: 0, delta_percent: nil)
      expect(report[:kpis][:first_response_time]).to eq(current: 1200, previous: nil, delta_percent: nil)
    end

    it 'includes every inbox of the account when no project is selected' do
      params.delete(:project_id)

      expect(report[:kpis][:total_chats][:current]).to eq(4)
      expect(report[:kpis][:incoming_messages][:current]).to eq(6)
    end
  end

  describe 'daily_channels' do
    it 'splits conversations per day into LINE, Facebook and others' do
      expect(report[:daily_channels].pluck(:date)).to eq(%w[2026-09-13 2026-09-14 2026-09-15 2026-09-16 2026-09-17 2026-09-18 2026-09-19])
      expect(report[:daily_channels][1]).to eq(date: '2026-09-14', line: 1, facebook: 0, others: 1, total: 2)
      expect(report[:daily_channels][4]).to eq(date: '2026-09-17', line: 1, facebook: 0, others: 0, total: 1)
      expect(report[:daily_channels].sum { |day| day[:total] }).to eq(3)
    end

    it 'buckets days in the requested timezone' do
      params[:timezone_offset] = '7'

      days = report[:daily_channels].index_by { |day| day[:date] }
      expect(days['2026-09-14'][:total]).to eq(1)
      expect(days['2026-09-15']).to eq(date: '2026-09-15', line: 0, facebook: 0, others: 1, total: 1)
    end
  end

  describe 'interval_summary' do
    it 'reports the peak hour, busiest day, busiest weekday and the share outside business hours' do
      expect(report[:interval_summary]).to eq(
        total: 3,
        peak_hour: { hour: 10, count: 2 },
        busiest_day: { date: '2026-09-14', count: 2 },
        busiest_weekday: { weekday: 1, average: 2.0 },
        outside_business_hours: { count: 0, percent: 0.0 }
      )
    end

    it 'buckets hours in the requested timezone' do
      params[:timezone_offset] = '7'

      expect(report[:interval_summary][:peak_hour]).to eq(hour: 17, count: 2)
      expect(report[:interval_summary][:outside_business_hours]).to eq(count: 1, percent: 33.3)
    end

    it 'returns empty cards when the period has no chats' do
      params[:since] = Time.utc(2026, 8, 1).to_i.to_s
      params[:until] = Time.utc(2026, 8, 8).to_i.to_s

      expect(report[:interval_summary]).to eq(total: 0, peak_hour: nil, busiest_day: nil, busiest_weekday: nil, outside_business_hours: nil)
    end
  end

  describe 'agent_load' do
    it 'counts open, pending and snoozed conversations for agents in the project inboxes' do
      expect(report[:agent_load]).to eq([
                                          { id: alice.id, name: 'Alice', assigned_count: 2, limit: 10 },
                                          { id: bob.id, name: 'Bob', assigned_count: 1, limit: 10 }
                                        ])
    end
  end

  it 'raises when the project belongs to another account' do
    params[:project_id] = Project.create!(account: create(:account), name: 'Other').id

    expect { report }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
