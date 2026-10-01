// The Thaimart CDP status set, in menu order. Only Ready gets chats assigned automatically.
// The n-* palette has no green or pink: Ready keeps the stock online teal, so the avatar
// badge and the Agents online dot agree, Rest room takes iris and Briefing takes ruby.
// Literal class strings, so Tailwind sees them.
export const AGENT_STATUSES = Object.freeze([
  {
    value: 'ready',
    color: 'bg-n-teal-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.READY',
  },
  {
    value: 'busy',
    color: 'bg-n-amber-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.BUSY',
  },
  {
    value: 'mini_break',
    color: 'bg-n-blue-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.MINI_BREAK',
  },
  {
    value: 'lunch',
    color: 'bg-n-violet-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.LUNCH',
  },
  {
    value: 'briefing',
    color: 'bg-n-ruby-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.BRIEFING',
  },
  {
    value: 'rest_room',
    color: 'bg-n-iris-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.REST_ROOM',
  },
  {
    value: 'offline',
    color: 'bg-n-slate-9',
    labelKey: 'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.OFFLINE',
  },
]);

export const getAgentStatusMeta = value =>
  AGENT_STATUSES.find(status => status.value === value) || AGENT_STATUSES[6];

// The stock availability each status derives to, as the server maps it.
export const AVAILABILITY_BY_STATUS = Object.freeze({
  ready: 'online',
  busy: 'busy',
  mini_break: 'busy',
  lunch: 'busy',
  briefing: 'busy',
  rest_room: 'busy',
  offline: 'offline',
});

const STATUS_BY_AVAILABILITY = Object.freeze({
  online: 'ready',
  busy: 'busy',
  offline: 'offline',
});

/**
 * The status to show for an agent from a list. Presence arrives live as the 3-way
 * availability_status, while agent_status is a snapshot from when the list was fetched, so
 * the picked status counts only while it still agrees with the live presence.
 */
export const liveAgentStatus = agent => {
  const live = agent.availability_status;
  return AVAILABILITY_BY_STATUS[agent.agent_status] === live
    ? agent.agent_status
    : STATUS_BY_AVAILABILITY[live] || 'offline';
};
