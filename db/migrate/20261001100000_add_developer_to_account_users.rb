# frozen_string_literal: true

class AddDeveloperToAccountUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :account_users, :developer, :boolean, default: false, null: false
  end
end
