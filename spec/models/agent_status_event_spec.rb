require 'rails_helper'

RSpec.describe AgentStatusEvent do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:account_user) { account.account_users.find_by(user: user) }
  let(:now) { Time.utc(2026, 10, 1, 12, 0, 0) }

  before { described_class.where(user_id: user.id).delete_all }

  def interval(status, from, to = nil)
    described_class.create!(account: account, user: user, agent_status: status, started_at: from, ended_at: to)
  end

  describe '.today_for' do
    it 'adds up each status and the online total, leaving offline out' do
      interval(:ready, now - 4.hours, now - 3.hours)
      interval(:lunch, now - 3.hours, now - 2.hours)
      interval(:offline, now - 2.hours, now - 1.hour)
      interval(:ready, now - 1.hour)

      today = described_class.today_for(account_user, now: now)

      expect(today).to include(ready: 7200, lunch: 3600, busy: 0, online_total: 10_800)
    end

    it 'counts an open interval up to now' do
      interval(:busy, now - 90.seconds)

      expect(described_class.today_for(account_user, now: now)[:busy]).to eq(90)
    end

    it 'counts an interval that began yesterday only from midnight' do
      interval(:ready, Time.utc(2026, 9, 30, 23, 0, 0))

      expect(described_class.today_for(account_user, now: now)[:ready]).to eq(12 * 3600)
    end

    it 'ignores an interval that ended before midnight' do
      interval(:ready, Time.utc(2026, 9, 30, 20, 0, 0), Time.utc(2026, 9, 30, 23, 0, 0))

      expect(described_class.today_for(account_user, now: now)[:online_total]).to eq(0)
    end

    it 'rolls the day at midnight in the account reporting timezone' do
      account.update!(reporting_timezone: 'Asia/Bangkok')
      interval(:ready, Time.utc(2026, 9, 30, 15, 0, 0))

      # Bangkok midnight is 17:00 UTC the day before, so by 12:00 UTC the day is 19 hours old
      expect(described_class.today_for(account_user, now: now)[:ready]).to eq(19 * 3600)
    end

    it 'rolls the day at UTC midnight when the account has no timezone' do
      interval(:ready, Time.utc(2026, 9, 30, 15, 0, 0))

      expect(described_class.today_for(account_user, now: now)[:ready]).to eq(12 * 3600)
    end

    it 'leaves another agent out' do
      interval(:ready, now - 1.hour)
      other = create(:user, account: account)
      described_class.create!(account: account, user: other, agent_status: :ready, started_at: now - 2.hours, ended_at: now - 1.hour)

      expect(described_class.today_for(account_user, now: now)[:ready]).to eq(3600)
    end
  end

  describe 'deletion' do
    it 'goes with a deleted user' do
      interval(:ready, now - 1.hour, now)
      interval(:busy, now)

      expect { user.destroy! }.to change { described_class.where(user_id: user.id).count }.from(2).to(0)
    end

    it 'goes with a deleted account' do
      interval(:ready, now)

      expect { account.destroy! }.to change { described_class.where(account_id: account.id).count }.from(1).to(0)
    end
  end

  describe '.switch!' do
    it 'does not move an interval end before its start' do
      opened = interval(:ready, now)

      described_class.switch!(account_user, :lunch, at: now - 1.hour)

      expect(opened.reload.ended_at).to eq(now)
      expect(described_class.open.find_by(user_id: user.id).started_at).to eq(now)
    end

    it 'returns nil when another writer already opened an interval' do
      interval(:ready, now)
      allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

      expect(described_class.switch!(account_user, :lunch)).to be_nil
    end
  end

  describe '.ready_cooling_down_user_ids' do
    it 'lists an agent who switched to Ready within the cool-down' do
      interval(:busy, now - 1.hour, now - 4.minutes)
      interval(:ready, now - 4.minutes)

      expect(described_class.ready_cooling_down_user_ids(account.id, now: now)).to eq([user.id])
    end

    it 'leaves out an agent whose switch to Ready is older than the cool-down' do
      interval(:busy, now - 1.hour, now - 6.minutes)
      interval(:ready, now - 6.minutes)

      expect(described_class.ready_cooling_down_user_ids(account.id, now: now)).to be_empty
    end

    it 'leaves out a new agent, who starts Ready without switching' do
      interval(:ready, now - 1.minute)

      expect(described_class.ready_cooling_down_user_ids(account.id, now: now)).to be_empty
    end

    it 'leaves out an agent who switched to another status' do
      interval(:ready, now - 1.hour, now - 1.minute)
      interval(:lunch, now - 1.minute)

      expect(described_class.ready_cooling_down_user_ids(account.id, now: now)).to be_empty
    end
  end
end
