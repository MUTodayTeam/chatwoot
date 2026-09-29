# == Schema Information
#
# Table name: case_categories
#
#  id                  :bigint           not null, primary key
#  c1                  :string           not null
#  c2                  :string           default(""), not null
#  c3                  :string           not null
#  inquiry_type        :integer          default("info"), not null
#  merge_key           :string           not null
#  sla_resolve_minutes :integer
#  sla_respond_minutes :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_case_categories_on_account_id_and_merge_key  (account_id,merge_key) UNIQUE
#
# The three-level topic an agent picks when solving a case: Category 1 › Category 2 › Category 3.
# A case without one is "Other". Named CaseCategory because Category is the help centre's.
class CaseCategory < ApplicationRecord
  LEVELS = %i[c1 c2 c3].freeze
  LEVEL_LENGTH = 255
  # A year, like LiveChatRule::MAX_MINUTES
  MAX_SLA_MINUTES = 525_600
  # Unicode spaces, plus the zero-width space and BOM that text pasted from the web or Excel carries
  EDGE_SPACE = /\A[[:space:]\u200B\uFEFF]+|[[:space:]\u200B\uFEFF]+\z/

  belongs_to :account

  enum :inquiry_type, { info: 0, request: 1, problem: 2 }, validate: true

  before_validation :normalize_levels

  validates :c1, :c3, presence: true
  validates(*LEVELS, length: { maximum: LEVEL_LENGTH })
  validates :merge_key, uniqueness: { scope: :account_id }
  validates :sla_respond_minutes, :sla_resolve_minutes,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_SLA_MINUTES }, allow_nil: true

  # Matches any of the three levels
  scope :search, lambda { |query|
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where('c1 ILIKE :pattern OR c2 ILIKE :pattern OR c3 ILIKE :pattern', pattern: pattern)
  }

  # Two rows naming the same path, whatever their case or surrounding spaces, are one category
  def self.merge_key_for(*levels)
    levels.map { |level| clean_level(level).downcase }.join('|')
  end

  def self.clean_level(level)
    level.to_s.unicode_normalize(:nfc).gsub(EDGE_SPACE, '')
  end

  private

  def normalize_levels
    LEVELS.each { |level| self[level] = self.class.clean_level(self[level]) }
    self.merge_key = self.class.merge_key_for(c1, c2, c3)
  end
end
