# frozen_string_literal: true

class CreateProjectTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :project_teams do |t|
      t.references :project, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :team, null: false, index: true, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :project_teams, [:project_id, :team_id], unique: true
  end
end
