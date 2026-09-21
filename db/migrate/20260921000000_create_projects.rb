# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :account, null: false, index: true
      t.string :name, null: false, limit: 255
      t.string :description
      t.string :color

      t.timestamps
    end

    add_index :projects, [:account_id, :name], unique: true

    add_reference :inboxes, :project, null: true, index: true
  end
end
