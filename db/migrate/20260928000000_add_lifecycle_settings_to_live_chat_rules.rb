class AddLifecycleSettingsToLiveChatRules < ActiveRecord::Migration[7.1]
  def change
    change_table :live_chat_rules, bulk: true do |t|
      # an open conversation nobody has picked up within this long counts as missed
      t.integer :waiting_time_minutes, null: false, default: 60
      t.integer :auto_solve_hours, null: false, default: 24
      t.integer :auto_close_hours, null: false, default: 48
      t.bigint :transfer_team_id
      t.decimal :assisted_weight, precision: 4, scale: 2, null: false, default: 0.5
      t.decimal :transfer_penalty, precision: 4, scale: 2, null: false, default: 0.2
    end
  end
end
