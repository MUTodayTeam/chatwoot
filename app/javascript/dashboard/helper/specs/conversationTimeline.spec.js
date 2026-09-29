import {
  ARRIVED_EVENT_ID,
  TIMELINE_TONES,
  buildConversationTimeline,
} from '../conversationTimeline';

const activity = (id, createdAt, attributes, content = `activity ${id}`) => ({
  id,
  message_type: 2,
  content,
  created_at: createdAt,
  content_attributes: { activity: attributes },
});

const build = (messages, isComplete = true) =>
  buildConversationTimeline({
    messages,
    isComplete,
    createdAt: 100,
    arrivedText: 'Arrived via LINE',
  });

describe('buildConversationTimeline', () => {
  it('ends with the conversation arriving through its channel', () => {
    expect(build([])).toEqual([
      {
        id: ARRIVED_EVENT_ID,
        text: 'Arrived via LINE',
        createdAt: 100,
        tone: TIMELINE_TONES.SYSTEM,
      },
    ]);
  });

  it('colours each event by what it is', () => {
    const tones = build([
      activity(1, 110, { type: 'assignee_changed' }),
      activity(2, 120, { type: 'assignee_changed' }),
      activity(3, 130, { type: 'team_changed' }),
      activity(4, 140, {
        type: 'conversation_status_changed',
        status: 'pending',
      }),
      activity(5, 150, { type: 'reply_deadline_extended' }),
      activity(6, 160, { type: 'case_opened' }),
      activity(7, 170, {
        type: 'conversation_status_changed',
        status: 'resolved',
      }),
      activity(8, 180, {
        type: 'conversation_status_changed',
        status: 'resolved',
        automated: true,
      }),
      activity(9, 190, {
        type: 'conversation_status_changed',
        status: 'closed',
        automated: true,
      }),
      activity(10, 200, {
        type: 'conversation_status_changed',
        status: 'closed',
      }),
    ]).map(({ id, tone }) => [id, tone]);

    expect(tones).toEqual([
      [10, TIMELINE_TONES.ACTION],
      [9, TIMELINE_TONES.SYSTEM],
      [8, TIMELINE_TONES.SYSTEM],
      [7, TIMELINE_TONES.ACCENT],
      [6, TIMELINE_TONES.ACCENT],
      [5, TIMELINE_TONES.SYSTEM],
      [4, TIMELINE_TONES.ACTION],
      [3, TIMELINE_TONES.ACTION],
      [2, TIMELINE_TONES.ACTION],
      [1, TIMELINE_TONES.ACTION],
      [ARRIVED_EVENT_ID, TIMELINE_TONES.SYSTEM],
    ]);
  });

  it('shows the activity text and time of each event', () => {
    const [event] = build([
      activity(
        4,
        140,
        { type: 'case_opened' },
        'Case #CK-1 opened automatically'
      ),
    ]);

    expect(event).toEqual({
      id: 4,
      text: 'Case #CK-1 opened automatically',
      createdAt: 140,
      tone: TIMELINE_TONES.ACCENT,
    });
  });

  it('puts the newest first, and the later message first within one second', () => {
    const ids = build([
      activity(3, 150, { type: 'assignee_changed' }),
      activity(5, 120, { type: 'case_opened' }),
      activity(4, 150, { type: 'case_opened' }),
    ]).map(event => event.id);

    expect(ids).toEqual([4, 3, 5, ARRIVED_EVENT_ID]);
  });

  it('leaves out messages and activities the timeline does not track', () => {
    const ids = build([
      { id: 1, message_type: 0, content: 'hi', created_at: 110 },
      { id: 2, message_type: 1, content: 'hello', created_at: 120 },
      activity(3, 130, { type: 'label_added' }),
      { id: 4, message_type: 2, content: 'muted', created_at: 140 },
    ]).map(event => event.id);

    expect(ids).toEqual([ARRIVED_EVENT_ID]);
  });

  it('leaves out the arrival while older activities may be missing', () => {
    const ids = build(
      [activity(1, 110, { type: 'assignee_changed' })],
      false
    ).map(event => event.id);

    expect(ids).toEqual([1]);
  });

  it('shows an activity once when both the history and the thread hold it', () => {
    const assigned = activity(1, 110, { type: 'assignee_changed' });

    expect(build([assigned, { ...assigned }]).map(event => event.id)).toEqual([
      1,
      ARRIVED_EVENT_ID,
    ]);
  });
});
