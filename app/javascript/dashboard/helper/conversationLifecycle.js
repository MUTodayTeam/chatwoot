import wootConstants from 'dashboard/constants/globals';

const { STATUS_TYPE } = wootConstants;

// The CDP lifecycle as agents see it. Bot, On Hold and Solved are not stored statuses:
// Bot is a pending conversation held by an AI assignee, On Hold is snoozed with no
// reopen time and Solved is resolved. A snoozed conversation with a reopen time keeps
// Chatwoot's own Snoozed.
export const LIFECYCLE_STATUS = {
  BOT: 'bot',
  OPEN: 'open',
  PENDING: 'pending',
  ON_HOLD: 'on_hold',
  SNOOZED: 'snoozed',
  SOLVED: 'solved',
  CLOSED: 'closed',
};

// The assignee types the conversation payload reports for an agent bot or a Captain assistant.
const AI_ASSIGNEE_TYPES = ['AgentBot', 'Captain::Assistant'];

export const BOT_STATUS_ICON = 'i-lucide-bot';

// The statuses an agent can pick, in lifecycle order, with what each one sends to toggle_status.
export const SELECTABLE_STATUSES = [
  {
    value: LIFECYCLE_STATUS.OPEN,
    status: STATUS_TYPE.OPEN,
    icon: 'i-woot-status-open',
  },
  {
    value: LIFECYCLE_STATUS.PENDING,
    status: STATUS_TYPE.PENDING,
    icon: 'i-woot-status-pending',
  },
  {
    value: LIFECYCLE_STATUS.ON_HOLD,
    status: STATUS_TYPE.SNOOZED,
    icon: 'i-woot-status-snoozed',
  },
  {
    value: LIFECYCLE_STATUS.SOLVED,
    status: STATUS_TYPE.RESOLVED,
    icon: 'i-woot-status-resolved',
  },
  {
    value: LIFECYCLE_STATUS.CLOSED,
    status: STATUS_TYPE.CLOSED,
    icon: 'i-lucide-lock',
  },
];

export const getLifecycleStatus = conversation => {
  const { status, snoozed_until: snoozedUntil, meta } = conversation;

  if (status === STATUS_TYPE.PENDING) {
    return AI_ASSIGNEE_TYPES.includes(meta?.assignee_type)
      ? LIFECYCLE_STATUS.BOT
      : LIFECYCLE_STATUS.PENDING;
  }
  if (status === STATUS_TYPE.SNOOZED) {
    return snoozedUntil ? LIFECYCLE_STATUS.SNOOZED : LIFECYCLE_STATUS.ON_HOLD;
  }
  if (status === STATUS_TYPE.RESOLVED) return LIFECYCLE_STATUS.SOLVED;
  return status;
};

// Closed follows resolved and only reopening leaves it, as the server enforces.
export const canChangeTo = (conversation, value) => {
  const { status } = conversation;
  if (status === STATUS_TYPE.CLOSED) return value === LIFECYCLE_STATUS.OPEN;
  if (value === LIFECYCLE_STATUS.CLOSED) {
    return status === STATUS_TYPE.RESOLVED;
  }
  // toggle_status keeps the reopen time while the status stays snoozed, so a timed
  // snooze has to be reopened before it can go on hold.
  if (value === LIFECYCLE_STATUS.ON_HOLD) {
    return getLifecycleStatus(conversation) !== LIFECYCLE_STATUS.SNOOZED;
  }
  return true;
};

// Snoozing until a set time stays where Chatwoot offers it: on open and resolved conversations.
export const canSnoozeUntil = ({ status }) =>
  [STATUS_TYPE.OPEN, STATUS_TYPE.RESOLVED].includes(status);
