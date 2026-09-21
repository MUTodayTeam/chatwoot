# frozen_string_literal: true

class CreateLiveChatRules < ActiveRecord::Migration[7.1]
  # No rules rows exist yet when this runs, so every conversation falls back to
  # the column default below.
  DEFAULT_REPLY_TIMEOUT_MINUTES = 60

  def up
    create_table :live_chat_rules do |t|
      t.references :account, null: false, index: true
      # null project is the account-wide default every project falls back to
      t.references :project, null: true, index: true
      t.integer :reply_timeout_minutes, null: false, default: DEFAULT_REPLY_TIMEOUT_MINUTES
      t.integer :extension_minutes, null: false, default: 60

      t.timestamps
    end

    add_index :live_chat_rules, [:account_id, :project_id], unique: true

    add_column :conversations, :reply_due_at, :datetime
    add_index :conversations, :reply_due_at

    backfill_reply_due_at
  end

  def down
    remove_column :conversations, :reply_due_at
    drop_table :live_chat_rules
  end

  private

  # Without this, chats that are already open when this ships show no countdown
  # until the customer happens to write again.
  def backfill_reply_due_at
    Conversation.where(status: :open).where.not(waiting_since: nil).in_batches(of: 10_000) do |batch|
      # rubocop:disable Rails/SkipsModelValidations
      batch.update_all("reply_due_at = waiting_since + interval '#{DEFAULT_REPLY_TIMEOUT_MINUTES} minutes'")
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
