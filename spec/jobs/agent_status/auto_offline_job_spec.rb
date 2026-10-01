require 'rails_helper'

RSpec.describe AgentStatus::AutoOfflineJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by(user: user) }
  let(:presence_key) { OnlineStatusTracker.presence_key(account.id, 'User') }

  # Ready since an hour ago, so a ping 10 minutes back falls inside that interval
  before { AgentStatusEvent.where(user_id: account_user.user_id).update_all(started_at: 1.hour.ago) } # rubocop:disable Rails/SkipsModelValidations

  def ping(seconds_ago)
    Redis::Alfred.zadd(presence_key, Time.current.to_i - seconds_ago, user.id)
  end

  it 'sets an agent whose last ping lapsed to offline, backdated to that ping' do
    ping(10.minutes.to_i)

    described_class.perform_now

    expect(account_user.reload).to be_agent_status_offline
    expect(AgentStatusEvent.where(user_id: user.id, agent_status: :ready).first.ended_at).to be_within(2.seconds).of(10.minutes.ago)
  end

  it 'sets an agent on lunch to offline too' do
    account_user.update!(agent_status: :lunch)
    AgentStatusEvent.open.update_all(started_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    ping(10.minutes.to_i)

    described_class.perform_now

    expect(account_user.reload).to be_agent_status_offline
  end

  it 'sets an agent with no ping at all to offline' do
    described_class.perform_now

    expect(account_user.reload).to be_agent_status_offline
  end

  it 'leaves an agent within the grace alone' do
    ping(2.minutes.to_i)

    described_class.perform_now

    expect(account_user.reload).to be_agent_status_ready
  end

  it 'leaves an agent whose status just began alone, however stale the last ping' do
    account_user.update!(agent_status: :busy)
    ping(1.hour.to_i)

    described_class.perform_now

    expect(account_user.reload).to be_agent_status_busy
  end

  it 'leaves an agent who turned auto offline off alone' do
    account_user.update!(auto_offline: false)

    described_class.perform_now

    expect(account_user.reload).to be_agent_status_ready
  end

  it 'leaves an agent who is already offline alone' do
    account_user.update!(agent_status: :offline)

    expect { described_class.perform_now }.not_to change(AgentStatusEvent, :count)
  end
end
