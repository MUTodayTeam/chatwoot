# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  color       :string
#  description :string
#  name        :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_projects_on_account_id           (account_id)
#  index_projects_on_account_id_and_name  (account_id,name) UNIQUE
#
class Project < ApplicationRecord
  belongs_to :account
  has_many :inboxes, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :account_id }
end
