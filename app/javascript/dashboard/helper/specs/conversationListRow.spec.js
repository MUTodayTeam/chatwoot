import {
  DEFAULT_AUTO_CLOSE_HOURS,
  findLiveChatRule,
  findProjectForInbox,
  formatCountdown,
  formatListRowTime,
  getAutoTransition,
  getChannelBadge,
  getStatusChipClass,
} from '../conversationListRow';

const HOUR = 3600;
const CHANGED_AT = 1_790_000_000;

const conversation = attrs => ({
  status: 'open',
  snoozed_until: null,
  meta: {},
  status_changed_at: CHANGED_AT,
  updated_at: CHANGED_AT + 0.5,
  ...attrs,
});

const defaultRule = {
  id: 1,
  projectId: null,
  autoSolveHours: 12,
  autoCloseHours: 36,
};
const projectRule = {
  id: 2,
  projectId: 5,
  autoSolveHours: 2,
  autoCloseHours: 4,
};

describe('getChannelBadge', () => {
  it.each([
    ['Channel::Line', 'LN'],
    ['Channel::FacebookPage', 'FB'],
    ['Channel::WebWidget', 'WB'],
    ['Channel::Instagram', 'IG'],
    ['Channel::Tiktok', 'TT'],
    ['Channel::Email', 'EM'],
  ])('maps %s to %s', (channelType, badge) => {
    expect(getChannelBadge(channelType)).toBe(badge);
  });

  it('marks an Instagram conversation from a Facebook Page inbox IG', () => {
    expect(
      getChannelBadge('Channel::FacebookPage', {
        type: 'instagram_direct_message',
      })
    ).toBe('IG');
  });

  it('has no badge for a channel outside the spec', () => {
    expect(getChannelBadge('Channel::Api')).toBe('');
    expect(getChannelBadge(undefined)).toBe('');
  });
});

describe('getStatusChipClass', () => {
  it('gives every lifecycle status its own solid chip', () => {
    const classes = [
      'bot',
      'open',
      'pending',
      'on_hold',
      'solved',
      'closed',
    ].map(getStatusChipClass);

    expect(new Set(classes).size).toBe(classes.length);
    classes.forEach(chipClass => {
      expect(chipClass).toMatch(/\bbg-n-/);
      // The active row is bg-n-alpha-2, so a translucent chip would vanish on it.
      expect(chipClass).not.toMatch(/\bbg-n-alpha-/);
    });
  });
});

describe('formatListRowTime', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 8, 29, 15, 0, 0));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('shows HH:MM for today', () => {
    const timestamp = new Date(2026, 8, 29, 9, 5).getTime() / 1000;
    expect(formatListRowTime(timestamp)).toBe('09:05');
  });

  it('shows dd/mm/yy before today', () => {
    const timestamp = new Date(2026, 8, 28, 23, 59).getTime() / 1000;
    expect(formatListRowTime(timestamp)).toBe('28/09/26');
  });

  it('shows the date once the day it is measured against has moved on', () => {
    const timestamp = new Date(2026, 8, 29, 9, 5).getTime() / 1000;
    expect(formatListRowTime(timestamp, new Date(2026, 8, 30, 0, 1))).toBe(
      '29/09/26'
    );
  });
});

describe('findProjectForInbox', () => {
  const projects = [
    { id: 5, name: 'Checkin', inboxIds: [1, 2] },
    { id: 6, name: 'MU', inboxIds: [3] },
  ];

  it('finds the project that holds the inbox', () => {
    expect(findProjectForInbox(projects, 3).name).toBe('MU');
  });

  it('returns null for an inbox in no project', () => {
    expect(findProjectForInbox(projects, 9)).toBeNull();
  });
});

describe('findLiveChatRule', () => {
  it("prefers the project's own rule", () => {
    expect(findLiveChatRule([defaultRule, projectRule], 5)).toBe(projectRule);
  });

  it('falls back to the account default', () => {
    expect(findLiveChatRule([defaultRule, projectRule], 6)).toBe(defaultRule);
    expect(findLiveChatRule([defaultRule, projectRule], null)).toBe(
      defaultRule
    );
  });

  it('returns null when no rule is saved', () => {
    expect(findLiveChatRule([], 5)).toBeNull();
  });
});

describe('getAutoTransition', () => {
  it('counts a resolved conversation to Closed on the project rule', () => {
    expect(
      getAutoTransition(conversation({ status: 'resolved' }), projectRule)
    ).toEqual({ target: 'closed', dueAt: CHANGED_AT + 4 * HOUR });
  });

  it('counts a resolved conversation on the account default rule', () => {
    expect(
      getAutoTransition(conversation({ status: 'resolved' }), defaultRule)
    ).toEqual({ target: 'closed', dueAt: CHANGED_AT + 36 * HOUR });
  });

  it('uses the column default when the account saved no rule', () => {
    expect(
      getAutoTransition(conversation({ status: 'resolved' }), null).dueAt
    ).toBe(CHANGED_AT + DEFAULT_AUTO_CLOSE_HOURS * HOUR);
  });

  it('counts from updated_at when status_changed_at was never set, as the sweep does', () => {
    expect(
      getAutoTransition(
        conversation({ status: 'resolved', status_changed_at: 0 }),
        projectRule
      ).dueAt
    ).toBe(CHANGED_AT + 4 * HOUR);
  });

  // The sweep leaves pending alone in an inbox with an active bot, whoever holds the
  // conversation, and the client cannot tell those inboxes apart.
  it.each([
    [
      'pending with an agent',
      { status: 'pending', meta: { assignee_type: 'User' } },
    ],
    ['pending with nobody', { status: 'pending', meta: {} }],
    ['bot', { status: 'pending', meta: { assignee_type: 'AgentBot' } }],
    ['open', { status: 'open' }],
    ['on hold', { status: 'snoozed' }],
    ['closed', { status: 'closed' }],
  ])('has no transition for a %s conversation', (_, attrs) => {
    expect(getAutoTransition(conversation(attrs), projectRule)).toBeNull();
  });
});

describe('formatCountdown', () => {
  it('formats hh:mm:ss', () => {
    expect(formatCountdown(26 * HOUR + 3 * 60 + 9)).toBe('26:03:09');
  });

  it('holds at zero once due', () => {
    expect(formatCountdown(-42)).toBe('00:00:00');
  });
});
