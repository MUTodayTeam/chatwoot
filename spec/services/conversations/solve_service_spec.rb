require 'rails_helper'

RSpec.describe Conversations::SolveService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }

  it 'resolves once when two solves loaded the conversation while it was open' do
    stale = Conversation.find(conversation.id)

    expect(described_class.new(conversation: Conversation.find(conversation.id), user: agent, send_survey: true).perform).to be_present
    expect(described_class.new(conversation: stale, user: agent, send_survey: true).perform).to be_nil
    perform_enqueued_jobs

    expect(ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_resolved').count).to eq(1)
    expect(conversation.messages.activity.pluck(:content).grep(/\ASolved/).size).to eq(1)
  end

  it 'files the case under the category with the summary, and records who solved it' do
    admin = create(:user, account: account, role: :administrator)
    category = create(:case_category, account: account, c3: 'Refund')
    Current.user = admin

    kase = described_class.new(conversation: Conversation.find(conversation.id), user: admin, case_category: category,
                               summary: 'Refunded', send_survey: true).perform

    expect(kase.reload).to have_attributes(case_category: category, summary: 'Refunded', resolved_by: admin)
    expect(Conversations::ActivityMessageJob).to have_been_enqueued
      .with(conversation, hash_including(content: 'Solved · Refund · closes automatically in 48 hours')).exactly(:once)
  ensure
    Current.reset
  end

  it "ends the assignee's turn as Solved, by whoever clicked it, before the resolve" do
    admin = create(:user, account: account, role: :administrator)

    described_class.new(conversation: Conversation.find(conversation.id), user: admin, send_survey: true).perform

    expect(conversation.handlers.pluck(:user_id, :end_reason, :ended_by_id)).to eq([[agent.id, 'solved', admin.id]])
  end

  describe '.survey_skipped!' do
    before do
      travel_to(Time.zone.parse('2026-09-29 10:00:00'))
      described_class.new(conversation: Conversation.find(conversation.id), user: agent, send_survey: false).perform
    end

    it 'leaves the skip to the resolve when a status change from before the solve is handled first' do
      expect(described_class.survey_skipped!(conversation, 1.minute.ago)).to be(false)
      expect(described_class.survey_skipped!(conversation, Time.zone.now)).to be(true)
      expect(described_class.survey_skipped!(conversation, Time.zone.now)).to be(false)
    end
  end
end
