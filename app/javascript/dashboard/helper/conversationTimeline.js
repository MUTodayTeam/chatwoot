import { MESSAGE_TYPE, CONVERSATION_STATUS } from 'shared/constants/messages';

// Spec §6: grey for what the system does, dark for assignments and status changes,
// accent for transfers, Solved and cases.
export const TIMELINE_TONES = Object.freeze({
  SYSTEM: 'system',
  ACTION: 'action',
  ACCENT: 'accent',
});

export const TIMELINE_TONE_CLASSES = Object.freeze({
  [TIMELINE_TONES.SYSTEM]: 'bg-n-slate-8',
  [TIMELINE_TONES.ACTION]: 'bg-n-slate-12',
  [TIMELINE_TONES.ACCENT]: 'bg-n-ruby-9',
});

const STATUS_CHANGED = 'conversation_status_changed';

// The activity types the timeline shows, read from content_attributes.activity.type.
const ACTIVITY_TONES = Object.freeze({
  assignee_changed: TIMELINE_TONES.ACTION,
  transferred: TIMELINE_TONES.ACCENT,
  team_changed: TIMELINE_TONES.ACTION,
  reply_deadline_extended: TIMELINE_TONES.SYSTEM,
  case_opened: TIMELINE_TONES.ACCENT,
});

export const ARRIVED_EVENT_ID = 'arrived';

// Custom::MessageFinder::ACTIVITY_LIMIT: a full page may leave older activities out.
export const TIMELINE_ACTIVITY_LIMIT = 200;

const activityTone = activity => {
  if (!activity) return null;
  if (activity.type !== STATUS_CHANGED) return ACTIVITY_TONES[activity.type];
  // The live chat rules solving or closing a conversation on their clock
  if (activity.automated) return TIMELINE_TONES.SYSTEM;
  return activity.status === CONVERSATION_STATUS.RESOLVED
    ? TIMELINE_TONES.ACCENT
    : TIMELINE_TONES.ACTION;
};

/**
 * The events of one conversation, newest first: its activity messages that say what
 * happened to it, then the conversation arriving through its channel once the
 * messages are known to hold its whole history.
 * @param {Object} params
 * @param {Array} params.messages - Messages as the API sends them; the same message may come twice
 * @param {boolean} params.isComplete - Whether the messages hold every activity since it arrived
 * @param {number} params.createdAt - When the conversation started, unix seconds
 * @param {string} params.arrivedText - What the first row says
 */
export const buildConversationTimeline = ({
  messages = [],
  isComplete,
  createdAt,
  arrivedText,
}) => {
  const activities = new Map(
    messages
      .filter(message => message.message_type === MESSAGE_TYPE.ACTIVITY)
      .map(message => [message.id, message])
  );
  const events = [...activities.values()]
    .map(message => ({
      id: message.id,
      text: message.content,
      createdAt: message.created_at,
      tone: activityTone(message.content_attributes?.activity),
    }))
    .filter(event => event.tone)
    .sort((a, b) => b.createdAt - a.createdAt || b.id - a.id);

  if (!isComplete) return events;

  return [
    ...events,
    {
      id: ARRIVED_EVENT_ID,
      text: arrivedText,
      createdAt,
      tone: TIMELINE_TONES.SYSTEM,
    },
  ];
};
