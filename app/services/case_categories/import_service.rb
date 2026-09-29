# Merges a category CSV into the account (spec 15): a row whose Category 1 › 2 › 3 already
# exists is skipped and its SLA left alone, a new one is added, and a row without Category 1 or
# Category 3 is invalid. Columns as CaseCategories::CsvService writes them.
class CaseCategories::ImportService
  # Excel's plain "CSV" on a Thai system is Windows-874; "CSV UTF-8" and our export are UTF-8
  FALLBACK_ENCODING = 'Windows-874'.freeze
  DEFAULT_INQUIRY_TYPE = 'request'.freeze

  pattr_initialize [:account!, :content!]

  def perform
    @existing_keys = CaseCategory.where(account_id: account.id).pluck(:merge_key).to_set
    @result = { added: [], skipped: 0, invalid: [] }
    CSV.parse(utf8_content).each_with_index do |row, index|
      next if row.all?(&:blank?) || (index.zero? && header?(row))

      # Line numbers as a spreadsheet shows them
      import_row(row, index + 1)
    end
    @result
  end

  private

  def utf8_content
    text = content.dup.force_encoding(Encoding::UTF_8)
    text = content.dup.force_encoding(FALLBACK_ENCODING).encode(Encoding::UTF_8) unless text.valid_encoding?
    text.delete_prefix(CaseCategories::CsvService::BOM)
  end

  def header?(row)
    row.first.to_s.strip.casecmp?(CaseCategories::CsvService::HEADERS.first)
  end

  def import_row(row, line)
    levels = CaseCategory::LEVELS.zip(row.first(3).map { |value| value.to_s.strip }).to_h
    return invalid(row, line, :missing_category) if levels[:c1].blank? || levels[:c3].blank?

    key = CaseCategory.merge_key_for(*levels.values)
    return @result[:skipped] += 1 if @existing_keys.include?(key)

    category = build_category(row, levels)
    category.is_a?(Symbol) ? invalid(row, line, category) : save(category, row, line, key)
  end

  # The category a row describes, or why it cannot be one
  def build_category(row, levels)
    sla, inquiry_type = row[3..4].map { |value| value.to_s.strip }
    type = inquiry_type.presence&.downcase || DEFAULT_INQUIRY_TYPE
    return :invalid_inquiry_type unless CaseCategory.inquiry_types.key?(type)

    respond, resolve = parse_sla(sla)
    return :invalid_sla if respond == :invalid

    CaseCategory.new(account: account, inquiry_type: type, sla_respond_minutes: respond, sla_resolve_minutes: resolve, **levels)
  end

  def parse_sla(text)
    CaseCategories::SlaText.parse(text)
  rescue ArgumentError
    :invalid
  end

  # Someone else adding the same category while this file is read makes it a skip, not an error
  def save(category, row, line, key)
    if category.save
      @existing_keys << key
      @result[:added] << category
    elsif category.errors.of_kind?(:merge_key, :taken)
      @result[:skipped] += 1
    else
      invalid(row, line, :invalid)
    end
  rescue ActiveRecord::RecordNotUnique
    @result[:skipped] += 1
  end

  def invalid(row, line, reason)
    @result[:invalid] << { line: line, values: row.map(&:to_s), reason: reason }
  end
end
