import {
  DELTA_TONES,
  buildDailyChannelChart,
  formatCount,
  formatDayWithWeekday,
  formatDeltaPercent,
  formatDuration,
  formatHourRange,
  getAgentLoadPercent,
  getDeltaTone,
  getWeekdayName,
  isAgentNearLimit,
} from './cdpDashboardHelper';

describe('cdpDashboardHelper', () => {
  describe('getDeltaTone', () => {
    it('treats growth as better for volume KPIs', () => {
      expect(getDeltaTone('totalChats', 12.5)).toBe(DELTA_TONES.BETTER);
      expect(getDeltaTone('incomingMessages', -3)).toBe(DELTA_TONES.WORSE);
    });

    it('treats a shorter first response as better', () => {
      expect(getDeltaTone('firstResponseTime', -20)).toBe(DELTA_TONES.BETTER);
      expect(getDeltaTone('firstResponseTime', 20)).toBe(DELTA_TONES.WORSE);
    });

    it('stays neutral without a change or without a delta', () => {
      expect(getDeltaTone('totalChats', 0)).toBe(DELTA_TONES.NEUTRAL);
      expect(getDeltaTone('totalChats', null)).toBe(DELTA_TONES.NEUTRAL);
    });
  });

  describe('formatDeltaPercent', () => {
    it('shows the direction and one decimal', () => {
      expect(formatDeltaPercent(12.34)).toBe('▲ 12.3%');
      expect(formatDeltaPercent(-50)).toBe('▼ 50.0%');
      expect(formatDeltaPercent(0)).toBe('▲ 0.0%');
    });

    it('shows a dash when there is nothing to compare against', () => {
      expect(formatDeltaPercent(null)).toBe('—');
    });
  });

  describe('formatDuration', () => {
    it('formats seconds as hh:mm:ss', () => {
      expect(formatDuration(0)).toBe('00:00:00');
      expect(formatDuration(3725)).toBe('01:02:05');
      expect(formatDuration(90061)).toBe('25:01:01');
    });

    it('shows a dash without a value', () => {
      expect(formatDuration(null)).toBe('—');
    });
  });

  describe('agent load', () => {
    it('warns from 90% of the limit', () => {
      expect(isAgentNearLimit({ assignedCount: 8, limit: 10 })).toBe(false);
      expect(isAgentNearLimit({ assignedCount: 9, limit: 10 })).toBe(true);
      expect(isAgentNearLimit({ assignedCount: 12, limit: 10 })).toBe(true);
    });

    it('caps the bar at a full width', () => {
      expect(getAgentLoadPercent({ assignedCount: 4, limit: 10 })).toBe(40);
      expect(getAgentLoadPercent({ assignedCount: 15, limit: 10 })).toBe(100);
      expect(getAgentLoadPercent({ assignedCount: 1, limit: 0 })).toBe(100);
    });
  });

  it('formats an hour as a one-hour range, wrapping at midnight', () => {
    expect(formatHourRange(9)).toBe('09:00 – 10:00');
    expect(formatHourRange(23)).toBe('23:00 – 00:00');
  });

  it('names a weekday from its index, Sunday first', () => {
    expect(getWeekdayName(0, 'en')).toBe('Sunday');
    expect(getWeekdayName(1, 'en')).toBe('Monday');
    expect(getWeekdayName(6, 'en')).toBe('Saturday');
  });

  it('accepts the underscore locale keys vue-i18n uses', () => {
    expect(getWeekdayName(1, 'pt_BR')).toBe('segunda-feira');
    expect(formatCount(1234, 'pt_BR')).toBe('1.234');
    expect(formatDayWithWeekday('2026-09-14', 'zh_CN')).toBe('14/09 (周一)');
  });

  it('names the busiest day with a weekday in the same locale', () => {
    expect(formatDayWithWeekday('2026-09-14', 'en')).toBe('14/09 (Mon)');
  });

  it('builds a stacked series per channel with the day total in the label', () => {
    const chart = buildDailyChannelChart(
      [
        { date: '2026-09-13', line: 3, facebook: 1, others: 0, total: 4 },
        { date: '2026-09-14', line: 0, facebook: 2, others: 5, total: 7 },
      ],
      [
        { key: 'line', label: 'LINE', color: 'red' },
        { key: 'others', label: 'Others', color: 'grey' },
      ]
    );

    expect(chart.categories).toEqual(['13/9 (4)', '14/9 (7)']);
    expect(chart.series).toEqual([
      { id: 'line', label: 'LINE', color: 'red', data: [3, 0] },
      { id: 'others', label: 'Others', color: 'grey', data: [0, 5] },
    ]);
  });
});
