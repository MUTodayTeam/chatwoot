# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  code        :string(10)
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
  include Avatarable

  belongs_to :account
  has_many :inboxes, dependent: :nullify
  has_many :live_chat_rules, dependent: :destroy
  has_many :cases, dependent: :nullify

  # The case number prefix, as in CK-858
  normalizes :code, with: ->(code) { code.strip.upcase.presence }

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :code, length: { maximum: 10 }, format: { with: /\A[A-Z0-9]+\z/ }, allow_nil: true
end
