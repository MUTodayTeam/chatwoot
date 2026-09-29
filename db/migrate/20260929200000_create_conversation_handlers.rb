# frozen_string_literal: true

class CreateConversationHandlers < ActiveRecord::Migration[7.1]
  def up
    # Who looked after a conversation, and from when to when. Each agent that took it gets a
    # row, which is what touch-based productivity credits.
    create_table :conversation_handlers do |t|
      t.references :account, null: false, index: false
      t.references :conversation, null: false, index: true
      t.references :user, null: false, index: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      # assign scope escalate shift general solved auto_solved unassigned
      t.integer :end_reason
      t.text :note
      t.references :ended_by, null: true, index: false

      t.timestamps
    end

    add_index :conversation_handlers, [:account_id, :user_id, :ended_at], name: 'index_conversation_handlers_on_account_user_ended_at'
    # A conversation has one agent at a time
    add_index :conversation_handlers, :conversation_id, unique: true, where: 'ended_at IS NULL',
                                                        name: 'index_conversation_handlers_open_per_conversation'

    open_turns_for_assigned_conversations
  end

  def down
    drop_table :conversation_handlers
  end

  private

  # Conversations an agent already holds (open, pending or on hold) get their turn from now
  # on, so solving them after this ships still credits that agent.
  def open_turns_for_assigned_conversations
    execute <<~SQL.squish
      INSERT INTO conversation_handlers (account_id, conversation_id, user_id, started_at, created_at, updated_at)
      SELECT account_id, id, assignee_id, NOW(), NOW(), NOW()
      FROM conversations
      WHERE assignee_id IS NOT NULL AND status IN (0, 2, 3)
    SQL
  end
end
