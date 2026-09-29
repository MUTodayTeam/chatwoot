import { ref } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import ConversationCardExpanded from '../ConversationCardExpanded.vue';

withFullI18n();

const getters = {
  'projects/getProjects': ref([{ id: 5, name: 'Checkin', inboxIds: [1] }]),
  'liveChatRules/getLiveChatRules': ref([
    { id: 2, projectId: 5, autoSolveHours: 2, autoCloseHours: 4 },
  ]),
};

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => getters[key],
}));

const NOW = 1_790_000_000;

const mountCard = (chat, props = {}) =>
  shallowMount(ConversationCardExpanded, {
    props: {
      chat: {
        id: 1,
        inbox_id: 1,
        labels: [],
        messages: [],
        meta: { channel: 'Channel::FacebookPage' },
        status: 'open',
        snoozed_until: null,
        unread_count: 0,
        timestamp: NOW,
        created_at: NOW,
        updated_at: NOW,
        status_changed_at: NOW,
        ...chat,
      },
      currentContact: { name: 'Jane Doe' },
      ...props,
    },
    global: {
      directives: { tooltip: {} },
      stubs: {
        CardAvatar: false,
        CardChannelBadge: false,
        CardTagRow: false,
        AutoTransitionCountdown: false,
      },
    },
  });

describe('ConversationCardExpanded', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW * 1000);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('puts the channel badge on the avatar', () => {
    expect(mountCard().findComponent({ name: 'CardChannelBadge' }).text()).toBe(
      'FB'
    );
  });

  it('shows the project, status and unassigned fallback', () => {
    const tags = mountCard().findComponent({ name: 'CardTagRow' }).text();

    expect(tags).toContain('Checkin');
    expect(tags).toContain('Open');
    expect(tags).toContain('— Unassigned');
  });

  it('shows the assignee only in the tag row', () => {
    const assigned = mountCard({}, { assignee: { name: 'Toon' } });
    const unassigned = mountCard();

    const avatarNames = assigned
      .findAllComponents({ name: 'Avatar' })
      .map(avatar => avatar.props('name'));
    const icons = unassigned
      .findAllComponents({ name: 'Icon' })
      .map(icon => icon.props('icon'));

    expect(avatarNames).not.toContain('Toon');
    expect(icons).not.toContain('i-woot-empty-assignee');
  });

  it('marks an Instagram conversation from a Facebook Page inbox IG', () => {
    const wrapper = mountCard({
      additional_attributes: { type: 'instagram_direct_message' },
    });

    expect(wrapper.findComponent({ name: 'CardChannelBadge' }).text()).toBe(
      'IG'
    );
  });

  it('counts a solved conversation down to Closed', () => {
    const wrapper = mountCard({ status: 'resolved' });

    expect(
      wrapper.findComponent({ name: 'AutoTransitionCountdown' }).text()
    ).toBe('→ Closed in 04:00:00');
  });

  it('bolds the name and shows the unread dot while unread', () => {
    const wrapper = mountCard({ unread_count: 1 });

    expect(wrapper.find('h4').classes()).toContain('font-extrabold');
    expect(wrapper.find('.bg-n-ruby-9').exists()).toBe(true);
  });

  it('marks the open conversation with the accent bar', () => {
    expect(
      mountCard({}, { isActiveChat: true }).find('.bg-n-brand').exists()
    ).toBe(true);
  });
});
