# frozen_string_literal: true

class AddProjectToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    # Null keeps the reply available in every project
    add_reference :canned_responses, :project, null: true, index: true
  end
end
