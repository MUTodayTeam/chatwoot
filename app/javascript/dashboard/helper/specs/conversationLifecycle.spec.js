import {
  LIFECYCLE_STATUS,
  canChangeTo,
  canSnoozeUntil,
  getLifecycleStatus,
} from '../conversationLifecycle';

const conversation = (status, extra = {}) => ({
  status,
  snoozed_until: null,
  meta: {},
  ...extra,
});

describe('conversationLifecycle', () => {
  describe('#getLifecycleStatus', () => {
    it('reports Bot for a pending conversation held by an agent bot or Captain', () => {
      ['AgentBot', 'Captain::Assistant'].forEach(assigneeType => {
        expect(
          getLifecycleStatus(
            conversation('pending', { meta: { assignee_type: assigneeType } })
          )
        ).toBe(LIFECYCLE_STATUS.BOT);
      });
    });

    it('reports Pending for a pending conversation with a human or no assignee', () => {
      expect(
        getLifecycleStatus(
          conversation('pending', { meta: { assignee_type: 'User' } })
        )
      ).toBe(LIFECYCLE_STATUS.PENDING);
      expect(getLifecycleStatus(conversation('pending'))).toBe(
        LIFECYCLE_STATUS.PENDING
      );
    });

    it('splits snoozed into On Hold and a timed Snoozed', () => {
      expect(getLifecycleStatus(conversation('snoozed'))).toBe(
        LIFECYCLE_STATUS.ON_HOLD
      );
      expect(
        getLifecycleStatus(
          conversation('snoozed', { snoozed_until: '2026-10-01T09:00:00Z' })
        )
      ).toBe(LIFECYCLE_STATUS.SNOOZED);
    });

    it('maps resolved to Solved and keeps open and closed', () => {
      expect(getLifecycleStatus(conversation('resolved'))).toBe(
        LIFECYCLE_STATUS.SOLVED
      );
      expect(getLifecycleStatus(conversation('open'))).toBe(
        LIFECYCLE_STATUS.OPEN
      );
      expect(getLifecycleStatus(conversation('closed'))).toBe(
        LIFECYCLE_STATUS.CLOSED
      );
    });
  });

  describe('#canChangeTo', () => {
    it('allows Closed only from resolved', () => {
      expect(canChangeTo(conversation('resolved'), 'closed')).toBe(true);
      ['open', 'pending', 'snoozed'].forEach(status => {
        expect(canChangeTo(conversation(status), 'closed')).toBe(false);
      });
    });

    it('allows only Open from closed', () => {
      const closed = conversation('closed');
      expect(canChangeTo(closed, 'open')).toBe(true);
      ['pending', 'on_hold', 'solved', 'closed'].forEach(value => {
        expect(canChangeTo(closed, value)).toBe(false);
      });
    });

    it('keeps a timed snooze from going straight to On Hold', () => {
      expect(
        canChangeTo(
          conversation('snoozed', { snoozed_until: '2026-10-01T09:00:00Z' }),
          'on_hold'
        )
      ).toBe(false);
      expect(canChangeTo(conversation('open'), 'on_hold')).toBe(true);
    });
  });

  describe('#canSnoozeUntil', () => {
    it('offers a timed snooze on open and resolved conversations only', () => {
      expect(
        ['open', 'resolved', 'pending', 'snoozed', 'closed'].filter(status =>
          canSnoozeUntil(conversation(status))
        )
      ).toEqual(['open', 'resolved']);
    });
  });
});
