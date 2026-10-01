require 'rails_helper'

RSpec.describe Custom::AccountUser do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by(user: user) }

  it 'starts an agent as ready and online' do
    expect(account_user).to be_agent_status_ready
    expect(account_user).to be_online
  end

  it 'opens one status event for a new agent' do
    expect(AgentStatusEvent.where(user_id: user.id).pluck(:agent_status)).to eq(['ready'])
  end

  %w[busy mini_break lunch briefing rest_room].each do |status|
    it "treats #{status} as busy availability" do
      account_user.update!(agent_status: status)

      expect(account_user.reload).to be_busy
    end
  end

  it 'reports an agent on lunch as busy to the presence tracker' do
    account_user.update!(agent_status: :lunch)

    expect(OnlineStatusTracker.get_status(account.id, user.id)).to eq('busy')
  end

  it 'derives offline availability from the offline status' do
    account_user.update!(agent_status: :offline)

    expect(account_user.reload).to be_offline
  end

  it 'maps a stock availability write back to a status' do
    account_user.update!(agent_status: :lunch)
    account_user.update!(availability: :online)

    expect(account_user.reload).to be_agent_status_ready
  end

  it 'maps stock busy and offline availability to the matching status' do
    account_user.update!(availability: :busy)
    expect(account_user.reload).to be_agent_status_busy

    account_user.update!(availability: :offline)
    expect(account_user.reload).to be_agent_status_offline
  end

  it 'starts an agent created offline as offline' do
    other = create(:account_user, account: account, user: create(:user), availability: :offline)

    expect(other).to be_agent_status_offline
  end

  it 'rejects an unknown status' do
    expect { account_user.update!(agent_status: 'nap') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  describe 'status events' do
    let(:events) { AgentStatusEvent.where(user_id: user.id).order(:id) }

    before { account_user }

    it 'closes the open event and opens the next on a change' do
      account_user.update!(agent_status: :lunch)

      expect(events.map(&:agent_status)).to eq(%w[ready lunch])
      expect(events.first.ended_at).to be_present
      expect(events.last.ended_at).to be_nil
    end

    it 'writes nothing when the status stays the same' do
      expect { account_user.update!(agent_status: :ready, auto_offline: false) }.not_to change(AgentStatusEvent, :count)
    end

    it 'backdates the change to agent_status_changed_at' do
      events.update_all(started_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
      at = 10.minutes.ago.change(usec: 0)
      account_user.agent_status_changed_at = at
      account_user.update!(agent_status: :offline)

      expect(events.first.reload.ended_at).to eq(at)
      expect(events.last.started_at).to eq(at)
    end

    it 'ends the open event when the agent is removed, so adding them back can open a new one' do
      account_user.destroy!

      expect(events.open).to be_empty
    end
  end
end
