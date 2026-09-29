# Writes the category CSV: A = Category 1, B = Category 2, C = Category 3, D = SLA, E = Inquiry Type.
# The BOM makes Excel read the file as UTF-8, which Thai text needs.
class CaseCategories::CsvService
  BOM = "\uFEFF".freeze
  HEADERS = ['Category 1', 'Category 2', 'Category 3', 'SLA (ตอบภายใน / ปิดภายใน)', 'Inquiry Type'].freeze
  # Excel runs a cell starting with one of these as a formula; a leading ' keeps it text
  FORMULA_START = /\A[=+\-@]/
  TEXT_MARK = "'".freeze

  def self.template
    BOM + CSV.generate_line(HEADERS)
  end

  def self.escape(level)
    level.match?(FORMULA_START) ? TEXT_MARK + level : level
  end

  # The level an exported cell stands for
  def self.unescape(cell)
    cell.start_with?(TEXT_MARK) && cell[1..].match?(FORMULA_START) ? cell[1..] : cell
  end

  def self.export(categories)
    BOM + CSV.generate do |csv|
      csv << HEADERS
      categories.each do |category|
        csv << [
          *[category.c1, category.c2, category.c3].map { |level| escape(level) },
          CaseCategories::SlaText.format(category.sla_respond_minutes, category.sla_resolve_minutes),
          category.inquiry_type.capitalize
        ]
      end
    end
  end
end
