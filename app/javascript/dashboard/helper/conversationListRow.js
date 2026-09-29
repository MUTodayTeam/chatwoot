import { format, fromUnixTime, isSameDay } from 'date-fns';
import {
  LIFECYCLE_STATUS,
  getLifecycleStatus,
} from 'dashboard/helper/conversationLifecycle';

// A solid chip per lifecycle status, in the spec's order of weight: Open is the darkest,
// On Hold carries the accent, Solved and Closed fade out.
export const STATUS_CHIP_CLASSES = Object.freeze({
  [LIFECYCLE_STATUS.BOT]: 'bg-n-iris-4 text-n-iris-11',
  [LIFECYCLE_STATUS.OPEN]: 'bg-n-slate-12 text-n-background',
  [LIFECYCLE_STATUS.PENDING]: 'bg-n-slate-5 text-n-slate-12',
  [LIFECYCLE_STATUS.ON_HOLD]: 'bg-n-blue-4 text-n-blue-11',
  [LIFECYCLE_STATUS.SNOOZED]: 'bg-n-blue-4 text-n-blue-11',
  [LIFECYCLE_STATUS.SOLVED]: 'bg-n-slate-10 text-n-background',
  [LIFECYCLE_STATUS.CLOSED]: 'bg-n-slate-3 text-n-slate-11',
});

export const getStatusChipClass = lifecycleStatus =>
  STATUS_CHIP_CLASSES[lifecycleStatus] ||
  STATUS_CHIP_CLASSES[LIFECYCLE_STATUS.CLOSED];

// Today's conversations show the time, older ones the date.
export const formatListRowTime = (timestamp, now = new Date()) => {
  if (!timestamp) return '';
  const date = fromUnixTime(timestamp);
  return format(date, isSameDay(date, now) ? 'HH:mm' : 'dd/MM/yy');
};

// The column default on live_chat_rules, which LiveChatRule.for_project also applies
// to an account that has saved no rule yet.
export const DEFAULT_AUTO_CLOSE_HOURS = 48;
const SECONDS_PER_HOUR = 3600;

// The projects list is read instead of inbox.project_id: inboxes come from an IndexedDB
// cache that only refreshes when an inbox changes (see ReplyDeadlineControl).
export const findProjectForInbox = (projects, inboxId) =>
  projects.find(project => project.inboxIds?.includes(inboxId)) || null;

// The project's own rule, else the account default, as LiveChatRule.for_project.
export const findLiveChatRule = (rules, projectId) =>
  (projectId && rules.find(rule => rule.projectId === projectId)) ||
  rules.find(rule => !rule.projectId) ||
  null;

/**
 * When LiveChatRules::SweepJob moves the conversation on by itself: Solved to Closed
 * after auto_close_hours.
 *
 * Pending to Solved is left out. The sweep skips pending conversations in an inbox
 * with an active bot (Inbox#active_bot?: an agent bot, Dialogflow, or Captain with
 * responses left), whoever they are assigned to, and nothing the client loads says
 * which inboxes those are, so a countdown there would run out with nothing happening.
 *
 * The clock starts at status_changed_at. Conversations from before v4.18.0 never had
 * it set, and the sweep counts those from updated_at instead (its STATUS_CLOCK).
 *
 * @returns {{ target: string, dueAt: number } | null} target lifecycle status and the
 *   unix time in seconds it is due
 */
export const getAutoTransition = (conversation, rule) => {
  if (getLifecycleStatus(conversation) !== LIFECYCLE_STATUS.SOLVED) return null;

  const since =
    conversation.status_changed_at || Math.floor(conversation.updated_at);
  const hours = rule?.autoCloseHours ?? DEFAULT_AUTO_CLOSE_HOURS;
  return {
    target: LIFECYCLE_STATUS.CLOSED,
    dueAt: since + hours * SECONDS_PER_HOUR,
  };
};

const pad = value => String(value).padStart(2, '0');

// hh:mm:ss, held at zero once due: the sweep runs every minute and catches up.
export const formatCountdown = seconds => {
  const total = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(total / SECONDS_PER_HOUR);
  const minutes = Math.floor((total % SECONDS_PER_HOUR) / 60);
  return `${pad(hours)}:${pad(minutes)}:${pad(total % 60)}`;
};
