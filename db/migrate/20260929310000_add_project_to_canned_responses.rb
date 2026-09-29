# frozen_string_literal: true

class AddProjectToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    # Null keeps the reply available in every project, which is also where a reply
    # lands if its project is deleted
    add_reference :canned_responses, :project, null: true, index: true, foreign_key: { on_delete: :nullify }
  end
end
