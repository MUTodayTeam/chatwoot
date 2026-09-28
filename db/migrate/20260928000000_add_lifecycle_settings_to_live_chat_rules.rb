class AddLifecycleSettingsToLiveChatRules < ActiveRecord::Migration[7.1]
  def change
    change_table :live_chat_rules, bulk: true do |t|
      # an open conversation nobody has picked up within this long counts as missed
      t.integer :waiting_time_minutes, null: false, default: 60
      t.integer :auto_solve_hours, null: false, default: 24
      t.integer :auto_close_hours, null: false, default: 48
      t.references :transfer_team, foreign_key: { to_table: :teams, on_delete: :nullify }
      t.decimal :assisted_weight, precision: 4, scale: 2, null: false, default: 0.5
      t.decimal :transfer_penalty, precision: 4, scale: 2, null: false, default: 0.2
    end

    # A unique index treats NULLs as distinct, so (account_id, project_id) alone lets an
    # account end up with two default rows.
    add_index :live_chat_rules, :account_id, unique: true, where: 'project_id IS NULL',
                                             name: 'index_live_chat_rules_on_account_id_default'
  end
end
