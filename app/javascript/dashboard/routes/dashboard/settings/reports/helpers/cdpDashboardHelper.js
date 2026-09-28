import format from 'date-fns/format';
import parseISO from 'date-fns/parseISO';

// A shorter first response is an improvement; every other KPI improves as it grows.
export const LOWER_IS_BETTER_KPIS = ['firstResponseTime'];

// With the default limit of 10 this marks an agent from 9 conversations on.
export const AGENT_LOAD_WARNING_RATIO = 0.9;

// A reference Sunday, so a weekday index (0 = Sunday) maps to a real date.
const REFERENCE_SUNDAY = new Date(2026, 0, 4);

export const DELTA_TONES = {
  BETTER: 'better',
  WORSE: 'worse',
  NEUTRAL: 'neutral',
};

export const getDeltaTone = (kpiKey, deltaPercent) => {
  if (deltaPercent === null || deltaPercent === undefined || deltaPercent === 0)
    return DELTA_TONES.NEUTRAL;

  const improved = LOWER_IS_BETTER_KPIS.includes(kpiKey)
    ? deltaPercent < 0
    : deltaPercent > 0;
  return improved ? DELTA_TONES.BETTER : DELTA_TONES.WORSE;
};

export const formatDeltaPercent = deltaPercent => {
  if (deltaPercent === null || deltaPercent === undefined) return '—';

  const arrow = deltaPercent >= 0 ? '▲' : '▼';
  return `${arrow} ${Math.abs(deltaPercent).toFixed(1)}%`;
};

// Seconds as hh:mm:ss; hours keep growing past 24 instead of rolling into days.
export const formatDuration = seconds => {
  if (seconds === null || seconds === undefined) return '—';

  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainder = Math.floor(seconds % 60);
  return [hours, minutes, remainder]
    .map(part => String(part).padStart(2, '0'))
    .join(':');
};

export const isAgentNearLimit = ({ assignedCount, limit }) =>
  assignedCount >= limit * AGENT_LOAD_WARNING_RATIO;

export const getAgentLoadPercent = ({ assignedCount, limit }) => {
  if (!limit) return 100;
  return Math.min(Math.round((assignedCount / limit) * 100), 100);
};

export const formatHourRange = hour =>
  `${String(hour).padStart(2, '0')}:00 – ${String((hour + 1) % 24).padStart(2, '0')}:00`;

export const getWeekdayName = (weekday, locale) => {
  const date = new Date(REFERENCE_SUNDAY);
  date.setDate(REFERENCE_SUNDAY.getDate() + weekday);
  return new Intl.DateTimeFormat(locale, { weekday: 'long' }).format(date);
};

// `series` lists { key, label, color } in stack order, bottom first.
export const buildDailyChannelChart = (dailyChannels, series) => ({
  categories: dailyChannels.map(
    day => `${format(parseISO(day.date), 'd/M')} (${day.total})`
  ),
  series: series.map(({ key, label, color }) => ({
    id: key,
    label,
    color,
    data: dailyChannels.map(day => day[key]),
  })),
});
