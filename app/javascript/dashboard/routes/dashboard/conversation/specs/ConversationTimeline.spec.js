import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import MessageApi from 'dashboard/api/inbox/message';
import ConversationTimeline from '../ConversationTimeline.vue';
import { TIMELINE_ACTIVITY_LIMIT } from 'dashboard/helper/conversationTimeline';

withFullI18n();

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(() => ({ name: 'Checkin+ LINE OA' })),
}));
vi.mock('dashboard/api/inbox/message', () => ({
  default: { getActivities: vi.fn() },
}));

const activity = (id, createdAt, type, content) => ({
  id,
  message_type: 2,
  content,
  created_at: createdAt,
  content_attributes: { activity: { type } },
});

const assigned = activity(
  5,
  1_800_000_060,
  'assignee_changed',
  'Assigned to Jason by Beam'
);
const caseOpened = activity(
  6,
  1_800_000_061,
  'case_opened',
  'Case #CK-1 opened automatically'
);

const mountTimeline = messages =>
  mount(ConversationTimeline, {
    props: {
      chat: { id: 12, inbox_id: 3, created_at: 1_800_000_000, messages },
    },
  });

const rowTexts = wrapper =>
  wrapper.findAll('li').map(row => row.find('p').text());

describe('ConversationTimeline', () => {
  beforeEach(() => {
    MessageApi.getActivities.mockReset();
  });

  it('lists the whole activity history newest first, past the page the thread loaded', async () => {
    // The assignment is older than the loaded page; only the case is in the thread.
    MessageApi.getActivities.mockResolvedValue({
      data: { payload: [assigned, caseOpened] },
    });
    const wrapper = mountTimeline([caseOpened]);
    await flushPromises();

    expect(MessageApi.getActivities).toHaveBeenCalledWith(12, {
      signal: expect.any(AbortSignal),
    });
    const rows = wrapper.findAll('li');
    expect(rowTexts(wrapper)).toEqual([
      'Case #CK-1 opened automatically',
      'Assigned to Jason by Beam',
      'Arrived via Checkin+ LINE OA',
    ]);
    expect(rows.map(row => row.find('span').classes())).toEqual([
      expect.arrayContaining(['bg-n-ruby-9']),
      expect.arrayContaining(['bg-n-slate-12']),
      expect.arrayContaining(['bg-n-slate-8']),
    ]);
  });

  it('adds an activity that arrives in the thread after the history loaded', async () => {
    MessageApi.getActivities.mockResolvedValue({
      data: { payload: [assigned] },
    });
    const wrapper = mountTimeline([]);
    await flushPromises();
    await wrapper.setProps({
      chat: { ...wrapper.props('chat'), messages: [caseOpened] },
    });

    expect(rowTexts(wrapper)).toEqual([
      'Case #CK-1 opened automatically',
      'Assigned to Jason by Beam',
      'Arrived via Checkin+ LINE OA',
    ]);
  });

  it('does not claim the arrival until the history has loaded', () => {
    MessageApi.getActivities.mockReturnValue(new Promise(() => {}));
    const wrapper = mountTimeline([caseOpened]);

    expect(rowTexts(wrapper)).toEqual(['Case #CK-1 opened automatically']);
  });

  it('does not claim the arrival when the history is cut at its limit', async () => {
    const payload = Array.from({ length: TIMELINE_ACTIVITY_LIMIT }, (_, i) =>
      activity(i + 1, 1_800_000_100 + i, 'assignee_changed', `row ${i}`)
    );
    MessageApi.getActivities.mockResolvedValue({ data: { payload } });
    const wrapper = mountTimeline([]);
    await flushPromises();

    expect(rowTexts(wrapper)).not.toContain('Arrived via Checkin+ LINE OA');
  });
});
