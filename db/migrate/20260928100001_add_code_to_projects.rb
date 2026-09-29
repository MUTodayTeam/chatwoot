# frozen_string_literal: true

class AddCodeToProjects < ActiveRecord::Migration[7.1]
  def change
    # Short prefix shown before a case number, such as CK in CK-858
    add_column :projects, :code, :string, limit: 10
  end
end
