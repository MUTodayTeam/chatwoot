import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../../vitest.i18n';
import CasesAPI from 'dashboard/api/cases';
import CasesIndex from '../CasesIndex.vue';

withFullI18n();

const NOW = 1_790_000_000;
const HOUR = 3600;

const getters = {
  'teams/getTeams': ref([]),
  'inboxes/getInbox': ref(() => ({ medium: '' })),
  'projects/getProjects': ref([{ id: 5, name: 'Checkin', inboxIds: [1] }]),
  'liveChatRules/getLiveChatRules': ref([]),
};
const RULES = [{ id: 2, projectId: 5, autoSolveHours: 2, autoCloseHours: 4 }];
const dispatch = vi.fn();
const replace = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => getters[key],
  useStore: () => ({ dispatch }),
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
  useRouter: () => ({ replace }),
}));
vi.mock('dashboard/api/cases', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useOpenConversationThread', () => ({
  useOpenConversationThread: () => vi.fn(),
}));

const buildCase = (id, status, statusChangedAt = NOW - HOUR) => ({
  id,
  display: `#${id}`,
  subject: 'Booking',
  severity: 'p3',
  status,
  reopened_count: 0,
  created_at: NOW,
  project: null,
  team: null,
  category: null,
  owner: null,
  contact: { id: 1, name: 'Nadol Resort' },
  conversation: {
    id,
    inbox_id: 1,
    channel: 'Channel::Line',
    status_changed_at: statusChangedAt,
  },
});

const respondWith = (payload, meta) =>
  CasesAPI.get.mockResolvedValueOnce({ data: { payload, meta } });

const mountPage = async () => {
  const wrapper = mount(CasesIndex, {
    global: {
      stubs: {
        TabBar: true,
        ContactProjectFilter: true,
        PaginationFooter: true,
        ChannelName: true,
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const rowOf = (wrapper, display) =>
  wrapper.findAll('tr').find(row => row.text().includes(display));

describe('CasesIndex', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW * 1000);
    CasesAPI.get.mockReset();
    dispatch.mockReset();
    getters['liveChatRules/getLiveChatRules'].value = RULES;
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('header counts', () => {
    it('shows the counts the API returns for the whole list', async () => {
      respondWith([buildCase(1, 'open')], { count: 12, open_count: 3 });
      const wrapper = await mountPage();

      expect(CasesAPI.get.mock.calls[0][0]).not.toHaveProperty('project_id');
      expect(wrapper.find('header p').text()).toBe('12 cases · 3 open');
    });

    it('asks for the selected project and shows its counts', async () => {
      respondWith([buildCase(1, 'open')], { count: 12, open_count: 3 });
      const wrapper = await mountPage();

      respondWith([buildCase(2, 'open')], { count: 1, open_count: 1 });
      wrapper
        .findComponent({ name: 'ContactProjectFilter' })
        .vm.$emit('update:modelValue', 5);
      await flushPromises();

      expect(CasesAPI.get.mock.calls[1][0]).toMatchObject({
        project_id: 5,
        page: 1,
      });
      expect(replace).toHaveBeenLastCalledWith({ query: { project_id: 5 } });
      expect(wrapper.find('header p').text()).toBe('1 case · 1 open');
    });
  });

  describe('countdown', () => {
    it("counts a solved case down to Closed with its project's rule", async () => {
      respondWith([buildCase(7, 'resolved')], { count: 1, open_count: 0 });
      const wrapper = await mountPage();

      // Solved an hour ago, closes after the rule's 4 hours
      expect(rowOf(wrapper, '#7').text()).toContain('→ Closed in 03:00:00');

      vi.advanceTimersByTime(1000);
      await flushPromises();
      expect(rowOf(wrapper, '#7').text()).toContain('→ Closed in 02:59:59');
    });

    it('shows no countdown for pending, open or closed cases', async () => {
      respondWith(
        [buildCase(1, 'pending'), buildCase(2, 'open'), buildCase(3, 'closed')],
        { count: 3, open_count: 2 }
      );
      const wrapper = await mountPage();

      expect(wrapper.text()).not.toContain('→');
    });

    it('loads the live chat rules when the store has none', async () => {
      getters['liveChatRules/getLiveChatRules'].value = [];
      respondWith([], { count: 0, open_count: 0 });
      await mountPage();

      expect(dispatch).toHaveBeenCalledWith('liveChatRules/get');
    });
  });
});
