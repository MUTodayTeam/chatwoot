import {
  CELL_INTENSITY_CLASSES,
  dayHeaderLabel,
  intensityClassFor,
  isWeekend,
} from './matrixCellHelper';

const daysFrom = (start, count) =>
  Array.from(
    { length: count },
    (_, index) =>
      new Date(start.getFullYear(), start.getMonth(), start.getDate() + index)
  );

describe('intensityClassFor', () => {
  it('returns no class for zero', () => {
    expect(intensityClassFor(0, 10)).toBe('');
  });

  it('uses the first band for the smallest non-zero value', () => {
    expect(intensityClassFor(1, 10)).toBe(CELL_INTENSITY_CLASSES[0]);
  });

  it('uses the fifth band for the maximum value', () => {
    expect(intensityClassFor(10, 10)).toBe(CELL_INTENSITY_CLASSES[4]);
  });

  it('clamps values above the maximum to the fifth band', () => {
    expect(intensityClassFor(11, 10)).toBe(CELL_INTENSITY_CLASSES[4]);
  });
});

describe('isWeekend', () => {
  it('identifies Saturday and Sunday as weekend days', () => {
    expect(isWeekend(new Date(2026, 7, 1))).toBe(true);
    expect(isWeekend(new Date(2026, 7, 2))).toBe(true);
  });

  it('does not identify a weekday as a weekend day', () => {
    expect(isWeekend(new Date(2026, 7, 3))).toBe(false);
  });
});

describe('dayHeaderLabel', () => {
  it('keeps dd/MM for a week', () => {
    const dates = daysFrom(new Date(2026, 8, 25), 7);

    expect(dates.map((_, index) => dayHeaderLabel(dates, index))).toEqual([
      '25/09',
      '26/09',
      '27/09',
      '28/09',
      '29/09',
      '30/09',
      '01/10',
    ]);
  });

  it('shows the day alone across 30 days, with the month where it starts', () => {
    const dates = daysFrom(new Date(2026, 8, 2), 30);
    const labels = dates.map((_, index) => dayHeaderLabel(dates, index));

    expect(labels[0]).toBe('2/9');
    expect(labels[1]).toBe('3');
    expect(labels[28]).toBe('30');
    expect(labels[29]).toBe('1/10');
  });
});
