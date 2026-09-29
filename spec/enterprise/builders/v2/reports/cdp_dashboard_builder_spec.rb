require 'rails_helper'

RSpec.describe V2::Reports::CdpDashboardBuilder do
  let!(:account) { create(:account) }
  let!(:project) { Project.create!(account: account, name: 'Share') }
  let!(:first_inbox) { create(:inbox, account: account, project: project) }
  let!(:second_inbox) { create(:inbox, account: account, project: project) }
  let!(:outside_inbox) { create(:inbox, account: account) }
  let!(:alice) { create(:user, account: account, name: 'Alice') }
  let!(:bob) { create(:user, account: account, name: 'Bob') }
  let!(:policy) { create(:agent_capacity_policy, account: account) }
  let(:params) { { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s, project_id: project.id } }
  let(:agent_load) { described_class.new(account: account, params: params).build[:agent_load] }

  before do
    create(:inbox_member, user: alice, inbox: first_inbox)
    create(:inbox_member, user: alice, inbox: second_inbox)
    create(:inbox_member, user: bob, inbox: first_inbox)
    create(:inbox_capacity_limit, agent_capacity_policy: policy, inbox: first_inbox, conversation_limit: 4)
    create(:inbox_capacity_limit, agent_capacity_policy: policy, inbox: second_inbox, conversation_limit: 3)
    create(:inbox_capacity_limit, agent_capacity_policy: policy, inbox: outside_inbox, conversation_limit: 20)
    alice.account_users.find_by(account: account).update!(agent_capacity_policy: policy)
  end

  context 'when advanced assignment is enabled' do
    before do
      account.enable_features('assignment_v2', 'advanced_assignment')
      account.save!
    end

    it 'sums the capacity limits on the project inboxes and keeps the default for agents without a policy' do
      expect(agent_load.map { |row| row.slice(:name, :limit) }).to contain_exactly(
        { name: 'Alice', limit: 7 },
        { name: 'Bob', limit: 10 }
      )
    end

    it 'counts a capped agent only on the inboxes that have a cap' do
      uncapped_inbox = create(:inbox, account: account, project: project)
      create(:inbox_member, user: alice, inbox: uncapped_inbox)
      create(:conversation, account: account, inbox: first_inbox, assignee: alice, status: :open)
      create(:conversation, account: account, inbox: second_inbox, assignee: alice, status: :snoozed)
      create_list(:conversation, 4, account: account, inbox: uncapped_inbox, assignee: alice, status: :open)
      create_list(:conversation, 2, account: account, inbox: uncapped_inbox, assignee: bob, status: :open)

      expect(agent_load.map { |row| row.slice(:name, :assigned_count, :limit) }).to eq([
                                                                                         { name: 'Alice', assigned_count: 2, limit: 7 },
                                                                                         { name: 'Bob', assigned_count: 2, limit: 10 }
                                                                                       ])
    end
  end

  context 'when advanced assignment is disabled' do
    it 'keeps the default limit' do
      expect(agent_load.pluck(:limit)).to eq([10, 10])
    end
  end
end
