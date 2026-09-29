class AddMissedAndExpiredToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :conversations, :missed_at, :datetime, if_not_exists: true
    add_column :conversations, :expired_at, :datetime, if_not_exists: true

    # Only a small share of conversations is ever flagged, and the reports only ever
    # look for flagged ones, so partial indexes stay small.
    add_index :conversations, [:account_id, :missed_at],
              where: 'missed_at IS NOT NULL',
              algorithm: :concurrently,
              if_not_exists: true
    add_index :conversations, [:account_id, :expired_at],
              where: 'expired_at IS NOT NULL',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
