import {
  autoCloseRemainingSeconds,
  findLiveChatRule,
  formatCountdown,
  showsEndBar,
} from '../conversationEndBar';

describe('conversationEndBar', () => {
  it('shows on solved and closed conversations only', () => {
    expect(showsEndBar({ status: 'resolved' })).toBe(true);
    expect(showsEndBar({ status: 'closed' })).toBe(true);
    ['open', 'pending', 'snoozed'].forEach(status => {
      expect(showsEndBar({ status })).toBe(false);
    });
  });

  describe('findLiveChatRule', () => {
    const rules = [
      { id: 1, projectId: null, autoCloseHours: 48 },
      { id: 2, projectId: 7, autoCloseHours: 12 },
    ];

    it('takes the project rule when the project has one', () => {
      expect(findLiveChatRule(rules, 7).id).toBe(2);
    });

    it('falls back to the account default', () => {
      expect(findLiveChatRule(rules, 9).id).toBe(1);
      expect(findLiveChatRule(rules, null).id).toBe(1);
    });
  });

  describe('autoCloseRemainingSeconds', () => {
    it('counts down from the moment the conversation was solved', () => {
      expect(
        autoCloseRemainingSeconds({
          statusChangedAt: 1000,
          autoCloseHours: 2,
          now: 1000 + 3600,
        })
      ).toBe(3600);
    });

    it('stops at zero once the time is up', () => {
      expect(
        autoCloseRemainingSeconds({
          statusChangedAt: 1000,
          autoCloseHours: 1,
          now: 1000 + 3600 + 30,
        })
      ).toBe(0);
    });
  });

  it('formats the countdown as hh:mm:ss, past 24 hours too', () => {
    expect(formatCountdown(48 * 3600)).toBe('48:00:00');
    expect(formatCountdown(3600 + 2 * 60 + 5)).toBe('01:02:05');
    expect(formatCountdown(0)).toBe('00:00:00');
  });
});
