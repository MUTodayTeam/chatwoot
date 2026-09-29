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
// conversation_transferred is the type the Transfer action tags its activity with.
const ACTIVITY_TONES = Object.freeze({
  assignee_changed: TIMELINE_TONES.ACTION,
  conversation_transferred: TIMELINE_TONES.ACCENT,
  reply_deadline_extended: TIMELINE_TONES.SYSTEM,
  case_opened: TIMELINE_TONES.ACCENT,
});

export const ARRIVED_EVENT_ID = 'arrived';

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
 * happened to it, then the conversation arriving through its channel.
 * @param {Object} params
 * @param {Array} params.messages - The conversation's loaded messages, as the API sends them
 * @param {number} params.createdAt - When the conversation started, unix seconds
 * @param {string} params.arrivedText - What the first row says
 */
export const buildConversationTimeline = ({
  messages = [],
  createdAt,
  arrivedText,
}) => {
  const events = messages
    .filter(message => message.message_type === MESSAGE_TYPE.ACTIVITY)
    .map(message => ({
      id: message.id,
      text: message.content,
      createdAt: message.created_at,
      tone: activityTone(message.content_attributes?.activity),
    }))
    .filter(event => event.tone)
    .sort((a, b) => b.createdAt - a.createdAt || b.id - a.id);

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
