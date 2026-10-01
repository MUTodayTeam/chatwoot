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
  'agentStatus/getAgentStatus': ref('ready'),
  'agentStatus/getLoad': ref({ active: 3, limit: 10 }),
  'agentStatus/getFetchedAt': ref(1),
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
    getters['agentStatus/getAgentStatus'].value = 'ready';
    getters['agentStatus/getLoad'].value = { active: 3, limit: 10 };
    getters['agentStatus/getFetchedAt'].value = 1;
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
    expect(dispatch).not.toHaveBeenCalledWith('agents/get');
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

  it("shows the agent's status and load as a pill", () => {
    const wrapper = mountStatus();

    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.PILL');
    expect(dispatch).toHaveBeenCalledWith('agentStatus/fetch', null);
  });

  it("measures the load against the current project's chat limit", () => {
    route.params = { projectId: '1' };

    mountStatus();

    expect(dispatch).toHaveBeenCalledWith('agentStatus/fetch', 1);
  });

  it('shows only the status until the load has been fetched', () => {
    getters['agentStatus/getLoad'].value = { active: 0, limit: 0 };

    const wrapper = mountStatus();

    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.STATUS.READY');
    expect(wrapper.text()).not.toContain('SIDEBAR_ITEMS.AGENT_STATUS.PILL');
  });

  it('hides the pill until the first fetch lands', () => {
    const pill = () => mountStatus().find('button').element.parentElement;

    expect(pill().classList.contains('hidden')).toBe(false);

    getters['agentStatus/getFetchedAt'].value = 0;
    expect(pill().classList.contains('hidden')).toBe(true);
  });
});
