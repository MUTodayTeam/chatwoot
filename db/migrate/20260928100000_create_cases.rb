# frozen_string_literal: true

class CreateCases < ActiveRecord::Migration[7.1]
  def change
    # One case per conversation an agent takes. Status and owner are read from the
    # conversation itself, so they are not stored here and cannot drift from it.
    create_table :cases do |t|
      t.references :account, null: false, index: false
      t.references :conversation, null: false, index: { unique: true }
      t.references :project, null: true, index: false
      t.references :team, null: true, index: false
      # Runs across the whole account, whichever project the case belongs to
      t.integer :display_id, null: false
      t.string :subject, null: false, default: ''
      # p1..p4, 3 = p4 (low)
      t.integer :severity, null: false, default: 3
      # Filled in by the category taxonomy
      t.bigint :case_category_id
      t.references :resolved_by, null: true, index: false
      t.integer :reopened_count, null: false, default: 0

      t.timestamps
    end

    add_index :cases, [:account_id, :display_id], unique: true
    add_index :cases, [:account_id, :project_id]
    add_index :cases, [:account_id, :team_id]
    add_index :cases, [:account_id, :created_at]
  end
end
