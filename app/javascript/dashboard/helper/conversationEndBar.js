import { CONVERSATION_STATUS } from 'shared/constants/messages';

const SECONDS_PER_HOUR = 3600;
const SECONDS_PER_MINUTE = 60;

// Matches the column default on live_chat_rules, used until the rules load.
export const DEFAULT_AUTO_CLOSE_HOURS = 48;

// Solved and Closed end the chat.
export const END_BAR_STATUSES = Object.freeze([
  CONVERSATION_STATUS.RESOLVED,
  CONVERSATION_STATUS.CLOSED,
]);

export const showsEndBar = ({ status }) => END_BAR_STATUSES.includes(status);

// The project's rule, else the account default, as LiveChatRule.for_project picks it.
export const findLiveChatRule = (rules, projectId) =>
  rules.find(rule => rule.projectId === projectId) ||
  rules.find(rule => !rule.projectId);

// Seconds until the sweep closes a solved conversation, never below zero: the sweep runs
// every minute, so the clock can reach zero a little before the conversation closes.
export const autoCloseRemainingSeconds = ({
  statusChangedAt,
  autoCloseHours,
  now,
}) => Math.max(0, statusChangedAt + autoCloseHours * SECONDS_PER_HOUR - now);

const pad = value => String(value).padStart(2, '0');

// hh:mm:ss, with hours past 24 kept as hours (48:00:00)
export const formatCountdown = totalSeconds => {
  const hours = Math.floor(totalSeconds / SECONDS_PER_HOUR);
  const minutes = Math.floor(
    (totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
  );
  const seconds = totalSeconds % SECONDS_PER_MINUTE;
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
};
