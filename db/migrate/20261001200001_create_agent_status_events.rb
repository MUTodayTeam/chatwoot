# frozen_string_literal: true

class CreateAgentStatusEvents < ActiveRecord::Migration[7.1]
  def up
    # One interval per stretch an agent spent in a status; the "today" summary adds them up.
    create_table :agent_status_events do |t|
      t.references :account, null: false, index: false
      t.references :user, null: false, index: false
      t.integer :agent_status, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_index :agent_status_events, [:account_id, :user_id, :started_at], name: 'index_agent_status_events_on_account_user_started_at'
    # An agent is in one status at a time
    add_index :agent_status_events, [:account_id, :user_id], unique: true, where: 'ended_at IS NULL',
                                                             name: 'index_agent_status_events_open_per_user'

    open_interval_for_each_agent
  end

  def down
    drop_table :agent_status_events
  end

  private

  # The summary starts at deploy, from the status each agent is in now.
  def open_interval_for_each_agent
    execute <<~SQL.squish
      INSERT INTO agent_status_events (account_id, user_id, agent_status, started_at, created_at, updated_at)
      SELECT account_id, user_id, agent_status, NOW(), NOW(), NOW()
      FROM account_users
      WHERE account_id IS NOT NULL AND user_id IS NOT NULL
    SQL
  end
end
