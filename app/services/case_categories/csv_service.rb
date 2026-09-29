# Writes the category CSV: A = Category 1, B = Category 2, C = Category 3, D = SLA, E = Inquiry Type.
# The BOM makes Excel read the file as UTF-8, which Thai text needs.
class CaseCategories::CsvService
  BOM = "\uFEFF".freeze
  HEADERS = ['Category 1', 'Category 2', 'Category 3', 'SLA (ตอบภายใน / ปิดภายใน)', 'Inquiry Type'].freeze

  def self.template
    BOM + CSV.generate_line(HEADERS)
  end

  def self.export(categories)
    BOM + CSV.generate do |csv|
      csv << HEADERS
      categories.each do |category|
        csv << [
          category.c1, category.c2, category.c3,
          CaseCategories::SlaText.format(category.sla_respond_minutes, category.sla_resolve_minutes),
          category.inquiry_type.capitalize
        ]
      end
    end
  end
end
