import { dayDividerLabel, dayLabel, startsNewDay } from '../dayDivider';

const at = (...args) => Math.floor(new Date(...args).getTime() / 1000);

describe('dayDivider', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 8, 29, 15, 0));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('dayLabel', () => {
    it('says Today for today', () => {
      expect(dayLabel(at(2026, 8, 29, 9, 30), 'Today')).toBe('Today');
    });

    it('shows the date without the year this year', () => {
      expect(dayLabel(at(2026, 8, 28, 23, 59), 'Today')).toBe('Sep 28');
    });

    it('adds the year for earlier years', () => {
      expect(dayLabel(at(2025, 11, 31, 10, 0), 'Today')).toBe('Dec 31, 2025');
    });
  });

  it('joins the day, the project and the channel, leaving out what is unknown', () => {
    const today = at(2026, 8, 29, 9, 30);

    expect(dayDividerLabel(today, 'Today', ['Checkin+', 'LINE OA'])).toBe(
      'Today · Checkin+ · LINE OA'
    );
    expect(dayDividerLabel(today, 'Today', [undefined, 'LINE OA'])).toBe(
      'Today · LINE OA'
    );
    expect(dayDividerLabel(at(2026, 8, 1, 9, 0), 'Today')).toBe('Sep 1');
  });

  it('opens a new day on the first message and on a change of date', () => {
    const morning = { createdAt: at(2026, 8, 28, 9, 0) };
    const evening = { createdAt: at(2026, 8, 28, 23, 0) };
    const nextDay = { createdAt: at(2026, 8, 29, 0, 5) };

    expect(startsNewDay(morning, undefined)).toBe(true);
    expect(startsNewDay(evening, morning)).toBe(false);
    expect(startsNewDay(nextDay, evening)).toBe(true);
  });
});
