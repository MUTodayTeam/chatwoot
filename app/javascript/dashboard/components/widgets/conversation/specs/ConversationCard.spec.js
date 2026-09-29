import { nextTick, ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { CONVERSATION_STATUS } from 'shared/constants/messages';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import ConversationCard from '../ConversationCard.vue';

withFullI18n();

const getters = {
  'projects/getProjects': ref([{ id: 5, name: 'Checkin', inboxIds: [1] }]),
  'liveChatRules/getLiveChatRules': ref([
    { id: 1, projectId: null, autoSolveHours: 24, autoCloseHours: 48 },
    { id: 2, projectId: 5, autoSolveHours: 2, autoCloseHours: 4 },
  ]),
};

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => getters[key],
}));

const NOW = 1_790_000_000;
const HOUR = 3600;

const defaultChat = {
  id: 1,
  labels: [],
  messages: [],
  priority: null,
  unread_count: 0,
  inbox_id: 1,
  meta: {},
  status: CONVERSATION_STATUS.OPEN,
  snoozed_until: null,
  timestamp: 1700000000,
  created_at: 1700000000,
  updated_at: 1700000000.5,
};

const mountComponent = (chat, currentContact = {}, props = {}) =>
  shallowMount(ConversationCard, {
    props: {
      chat: { ...defaultChat, ...chat },
      currentContact: {
        name: 'Jane Doe',
        thumbnail: '',
        availability_status: 'offline',
        ...currentContact,
      },
      inbox: { id: 1 },
      ...props,
    },
    global: {
      stubs: {
        'fluent-icon': true,
        ReplyCountdown: false,
        CardTagRow: false,
        CardChannelBadge: false,
        AutoTransitionCountdown: false,
      },
    },
  });

describe('ConversationCard', () => {
  it('does not reserve the labels row when only a persisted SLA policy id is present', () => {
    const wrapper = mountComponent({ sla_policy_id: 1, applied_sla: null });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('shows the labels row when an active applied SLA is present', () => {
    const wrapper = mountComponent({
      sla_policy_id: 1,
      applied_sla: { id: 1 },
    });

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(true);
  });

  it('does not reserve the labels row when the contact is blocked', () => {
    const wrapper = mountComponent(
      {
        sla_policy_id: 1,
        applied_sla: { id: 1 },
      },
      { blocked: true }
    );

    expect(wrapper.findComponent({ name: 'CardLabels' }).exists()).toBe(false);
  });

  it('uses the bot icon for a Captain assignee', () => {
    const wrapper = mountComponent(
      { meta: { assignee_type: 'Captain::Assistant' } },
      {},
      { assignee: { name: 'Captain' } }
    );

    expect(wrapper.findComponent({ name: 'Icon' }).props('icon')).toBe(
      'i-lucide-bot'
    );
  });

  it('puts the channel badge on the avatar', () => {
    const wrapper = mountComponent({ meta: { channel: 'Channel::Line' } });

    expect(wrapper.findComponent({ name: 'CardChannelBadge' }).text()).toBe(
      'LN'
    );
  });

  it('shows the project, the agent and the unassigned fallback in the tag row', () => {
    const assigned = mountComponent({}, {}, { assignee: { name: 'Toon' } });
    const tags = assigned.findComponent({ name: 'CardTagRow' }).text();

    expect(tags).toContain('Checkin');
    expect(tags).toContain('Toon');
    expect(
      mountComponent().findComponent({ name: 'CardTagRow' }).text()
    ).toContain('— Unassigned');
  });

  it('bolds the name and shows the unread dot while unread', () => {
    const unread = mountComponent({ unread_count: 2 });
    const read = mountComponent({ unread_count: 0 });

    expect(unread.find('h4').classes()).toContain('font-extrabold');
    expect(unread.find('.bg-n-ruby-9').exists()).toBe(true);
    expect(read.find('h4').classes()).not.toContain('font-extrabold');
    expect(read.find('.bg-n-ruby-9').exists()).toBe(false);
  });

  it('marks the open conversation with the accent bar', () => {
    const active = mountComponent({}, {}, { isActiveChat: true });

    expect(active.find('.bg-n-brand').exists()).toBe(true);
    expect(mountComponent().find('.bg-n-brand').exists()).toBe(false);
  });

  describe('per status', () => {
    beforeEach(() => {
      vi.useFakeTimers();
      vi.setSystemTime(NOW * 1000);
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it.each([
      ['Open', { status: 'open' }],
      ['Bot', { status: 'pending', meta: { assignee_type: 'AgentBot' } }],
      ['On Hold', { status: 'snoozed' }],
      ['Closed', { status: 'closed' }],
    ])(
      'labels a %s conversation and shows no auto-transition',
      (label, attrs) => {
        const wrapper = mountComponent({ status_changed_at: NOW, ...attrs });

        expect(wrapper.findComponent({ name: 'CardTagRow' }).text()).toContain(
          label
        );
        expect(wrapper.text()).not.toContain('→');
      }
    );

    it("counts a pending conversation down to Solved on its project's rule", () => {
      const wrapper = mountComponent({
        status: 'pending',
        status_changed_at: NOW - 30 * 60,
      });

      expect(wrapper.findComponent({ name: 'CardTagRow' }).text()).toContain(
        'Pending'
      );
      expect(
        wrapper.findComponent({ name: 'AutoTransitionCountdown' }).text()
      ).toBe('→ Solved in 01:30:00');
    });

    it('counts a solved conversation down to Closed', () => {
      const wrapper = mountComponent({
        status: 'resolved',
        status_changed_at: NOW - HOUR,
      });

      expect(wrapper.findComponent({ name: 'CardTagRow' }).text()).toContain(
        'Solved'
      );
      expect(
        wrapper.findComponent({ name: 'AutoTransitionCountdown' }).text()
      ).toBe('→ Closed in 03:00:00');
    });

    it('ticks the countdown every second', async () => {
      const wrapper = mountComponent({
        status: 'pending',
        status_changed_at: NOW - 30 * 60,
      });

      await vi.advanceTimersByTimeAsync(5000);
      await nextTick();

      expect(
        wrapper.findComponent({ name: 'AutoTransitionCountdown' }).text()
      ).toBe('→ Solved in 01:29:55');
    });
  });

  it('shows the reply countdown on an open conversation', () => {
    const wrapper = mountComponent({
      status: CONVERSATION_STATUS.OPEN,
      reply_due_at: Math.floor(Date.now() / 1000) + 600,
    });

    expect(wrapper.find('.i-lucide-timer').exists()).toBe(true);
  });

  it.each([
    CONVERSATION_STATUS.PENDING,
    CONVERSATION_STATUS.SNOOZED,
    CONVERSATION_STATUS.RESOLVED,
  ])('hides the reply countdown on a %s conversation', status => {
    const wrapper = mountComponent({
      status,
      reply_due_at: Math.floor(Date.now() / 1000) + 600,
    });

    expect(wrapper.find('.i-lucide-timer').exists()).toBe(false);
  });
});
