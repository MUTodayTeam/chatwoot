# frozen_string_literal: true

class AddAgentStatusToAccountUsers < ActiveRecord::Migration[7.1]
  def up
    # ready busy mini_break lunch briefing rest_room offline. Defaults to ready, as the stock
    # availability defaults to online; "Busy on login" is written at sign-in, not by the column.
    add_column :account_users, :agent_status, :integer, null: false, default: 0, if_not_exists: true

    # availability: online 0, offline 1, busy 2
    execute <<~SQL.squish
      UPDATE account_users
      SET agent_status = CASE availability WHEN 0 THEN 0 WHEN 1 THEN 6 ELSE 1 END
    SQL
  end

  def down
    remove_column :account_users, :agent_status
  end
end
