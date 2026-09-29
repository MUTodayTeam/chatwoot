# frozen_string_literal: true

class CreateCaseCategories < ActiveRecord::Migration[7.1]
  def change
    # The three-level topic an agent picks when solving a case
    create_table :case_categories do |t|
      t.references :account, null: false, index: false
      # info, request, problem
      t.integer :inquiry_type, null: false, default: 0
      t.string :c1, null: false
      t.string :c2, null: false, default: ''
      t.string :c3, null: false
      # lower(trim(c1))|lower(trim(c2))|lower(trim(c3)): one category per topic path
      t.string :merge_key, null: false
      t.integer :sla_respond_minutes
      t.integer :sla_resolve_minutes

      t.timestamps
    end

    add_index :case_categories, [:account_id, :merge_key], unique: true

    add_index :cases, :case_category_id
    # Deleting a category leaves its cases under "Other"
    add_foreign_key :cases, :case_categories, on_delete: :nullify
    # The agent's one-line summary when solving
    add_column :cases, :summary, :string
  end
end
