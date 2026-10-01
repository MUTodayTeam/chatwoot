import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import SidebarProjectStatus from '../SidebarProjectStatus.vue';

const dispatch = vi.fn();
const route = { params: {} };

const getters = {
  'projects/getProjects': ref([
    { id: 1, name: 'Checkin+', color: '#ff0000', inboxIds: [11, 12] },
  ]),
  'agents/getAgents': ref([]),
  getChatListFilters: ref({}),
  getAppliedConversationFilters: ref([]),
  'conversationStats/getStats': ref({ allCount: 17 }),
  'conversationUnreadCounts/getInboxUnreadCount': ref(inboxId =>
    inboxId === 11 ? 4 : 0
  ),
};

vi.mock('vue-router', () => ({ useRoute: () => route }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => getters[name],
  useStore: () => ({ dispatch }),
}));

const mountStatus = () => mount(SidebarProjectStatus);

describe('SidebarProjectStatus', () => {
  beforeEach(() => {
    dispatch.mockReset();
    route.params = {};
    getters['agents/getAgents'].value = [];
    getters.getChatListFilters.value = {};
  });

  it('fetches agents when none are loaded', () => {
    const wrapper = mountStatus();

    expect(wrapper.text()).toContain('SIDEBAR.PROJECT_STATUS.AGENTS_ONLINE');
    expect(wrapper.find('.tabular-nums').text()).toBe('0');
    expect(dispatch).toHaveBeenCalledWith('agents/get');
  });

  it('counts the online agents and leaves developers out', () => {
    getters['agents/getAgents'].value = [
      { id: 1, availability_status: 'online', developer: true },
      { id: 2, availability_status: 'online', developer: false },
      { id: 3, availability_status: 'busy', developer: false },
      { id: 4, availability_status: 'online' },
    ];

    const wrapper = mountStatus();

    expect(wrapper.find('.tabular-nums').text()).toBe('2');
  });

  it('shows no project on a list that spans every project', () => {
    getters['agents/getAgents'].value = [{ id: 1 }];

    const wrapper = mountStatus();

    expect(wrapper.text()).not.toContain('Checkin+');
    expect(dispatch).not.toHaveBeenCalled();
  });

  it("shows the project's open count on its own open list", () => {
    route.params = { projectId: '1' };
    getters.getChatListFilters.value = { projectId: '1', status: 'active' };

    const wrapper = mountStatus();

    expect(wrapper.text()).toContain('Checkin+');
    expect(wrapper.text()).toContain('SIDEBAR.PROJECT_STATUS.OPEN');
  });

  it("falls back to the project's unread count inside one of its channels", () => {
    route.params = { inbox_id: '12' };
    getters.getChatListFilters.value = { inboxId: 12, status: 'active' };

    const wrapper = mountStatus();

    expect(wrapper.text()).toContain('Checkin+');
    expect(wrapper.text()).toContain('SIDEBAR.PROJECT_STATUS.UNREAD');
  });
});
