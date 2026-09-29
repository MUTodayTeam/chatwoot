# The SLA column of the category CSV: "respond within / resolve within", such as "15 นาที / 1 วัน".
# The words are the spec's file format, not UI copy, so both Thai and English units are read
# whatever the account's locale, and a blank or a dash means no SLA.
module CaseCategories::SlaText
  SEPARATOR = ' / '.freeze
  NONE = '—'.freeze
  NONE_VALUES = ['', '-', '—', '–'].freeze
  MINUTES_PER = { day: 1440, hour: 60, minute: 1 }.freeze
  # Written on export, largest unit that divides evenly first
  UNIT_LABELS = { day: 'วัน', hour: 'ชม.', minute: 'นาที' }.freeze
  UNIT_WORDS = {
    minute: ['', 'นาที', 'm', 'min', 'mins', 'minute', 'minutes'],
    hour: ['ชม.', 'ชม', 'ชั่วโมง', 'h', 'hr', 'hrs', 'hour', 'hours'],
    day: %w[วัน d day days]
  }.freeze
  PART_PATTERN = /\A(\d+)\s*(\S*)\z/

  module_function

  # "15 นาที / 1 วัน" => [15, 1440]; raises ArgumentError on anything else
  def parse(text)
    parts = text.to_s.split('/').map(&:strip)
    raise ArgumentError, text if parts.size > 2

    [parse_part(parts[0]), parse_part(parts[1])]
  end

  def format(respond_minutes, resolve_minutes)
    return '' if respond_minutes.nil? && resolve_minutes.nil?

    [format_part(respond_minutes), format_part(resolve_minutes)].join(SEPARATOR)
  end

  def parse_part(part)
    return if NONE_VALUES.include?(part.to_s)

    match = PART_PATTERN.match(part)
    raise ArgumentError, part unless match

    unit = UNIT_WORDS.find { |_, words| words.include?(match[2].downcase) }&.first
    raise ArgumentError, part unless unit

    match[1].to_i * MINUTES_PER[unit]
  end

  def format_part(minutes)
    return NONE if minutes.nil?

    unit = MINUTES_PER.find { |_, per| (minutes % per).zero? }.first
    "#{minutes / MINUTES_PER[unit]} #{UNIT_LABELS[unit]}"
  end
end
