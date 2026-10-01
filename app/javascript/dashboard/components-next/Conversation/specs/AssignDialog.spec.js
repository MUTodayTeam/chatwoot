import { nextTick, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import AssignDialog from '../AssignDialog.vue';

const dispatch = vi.fn();

const getters = {
  'inboxAssignableAgents/getAssignableAgents': ref(() => [
    {
      id: 2,
      name: 'Poy',
      email: 'poy@example.com',
      availability_status: 'offline',
      conversation_load: { assigned_count: 3, limit: 10 },
    },
    {
      id: 3,
      name: 'Arm',
      email: 'arm@example.com',
      availability_status: 'offline',
      conversation_load: { assigned_count: 10, limit: 10 },
    },
  ]),
  'agents/getAgents': ref([{ id: 2, availability_status: 'online' }]),
  getCurrentUser: ref({ id: 1, accounts: [{ id: 7 }] }),
  getCurrentAccountId: ref(7),
  'projects/getProjects': ref([{ id: 5, inboxIds: [9], teamIds: [10] }]),
  'teams/getTeams': ref([
    { id: 10, name: 'CRM' },
    { id: 11, name: 'Dev' },
  ]),
  'teamMembers/getTeamMembers': ref(teamId =>
    teamId === 10 ? [{ id: 2 }] : []
  ),
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => getters[name],
  useStore: () => ({ dispatch }),
}));

const DialogStub = {
  name: 'Dialog',
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const mountDialog = async () => {
  const wrapper = mount(AssignDialog, {
    props: { conversationId: 42, inboxId: 9 },
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open();
  await flushPromises();
  return wrapper;
};

const agentRows = wrapper =>
  wrapper.findAll('button').filter(button => button.find('.truncate').exists());

describe('AssignDialog', () => {
  beforeEach(() => {
    dispatch.mockReset();
    dispatch.mockResolvedValue();
    useAlert.mockReset();
  });

  it("fetches the inbox's assignable agents and the project teams' members", async () => {
    await mountDialog();

    expect(dispatch).toHaveBeenCalledWith('inboxAssignableAgents/fetch', [9]);
    expect(dispatch).toHaveBeenCalledWith('teamMembers/get', { teamId: 10 });
    expect(dispatch).not.toHaveBeenCalledWith('teamMembers/get', {
      teamId: 11,
    });
  });

  it('lists each agent with their team, presence and load, online first', async () => {
    const wrapper = await mountDialog();
    const rows = agentRows(wrapper);

    expect(rows.map(row => row.text())).toEqual([
      expect.stringContaining('Poy'),
      expect.stringContaining('Arm'),
    ]);
    expect(rows[0].text()).toContain('CRM');
    expect(rows[0].text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.STATUS.READY');
    expect(rows[0].text()).toContain('3/10');
    expect(rows[1].text()).toContain(
      'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.OFFLINE'
    );
    expect(rows[1].find('.text-n-ruby-11').text()).toBe('10/10');
  });

  it('names the status an agent picked while it matches their live presence', async () => {
    const agents = getters['agents/getAgents'].value;
    getters['agents/getAgents'].value = [
      { id: 2, availability_status: 'busy' },
    ];
    const assignable = getters['inboxAssignableAgents/getAssignableAgents'];
    const original = assignable.value;
    assignable.value = () => [
      { ...original()[0], agent_status: 'lunch' },
      original()[1],
    ];

    const wrapper = await mountDialog();

    expect(agentRows(wrapper)[0].text()).toContain(
      'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.LUNCH'
    );
    getters['agents/getAgents'].value = agents;
    assignable.value = original;
  });

  it('hides the previous load while it refetches on reopen', async () => {
    const wrapper = await mountDialog();
    const pendingFetches = [];
    dispatch.mockImplementation(
      () =>
        new Promise(resolve => {
          pendingFetches.push(resolve);
        })
    );

    wrapper.vm.open();
    await nextTick();
    expect(agentRows(wrapper)).toHaveLength(0);

    pendingFetches.forEach(resolve => resolve());
    await flushPromises();
    expect(agentRows(wrapper)).toHaveLength(2);
  });

  it('narrows the list with the search box', async () => {
    const wrapper = await mountDialog();

    await wrapper.find('input').setValue('arm');

    expect(agentRows(wrapper).map(row => row.text())).toEqual([
      expect.stringContaining('Arm'),
    ]);

    await wrapper.find('input').setValue('nobody');
    expect(wrapper.text()).toContain('CONVERSATION.ASSIGN_DIALOG.NO_RESULTS');
  });

  it('assigns the picked agent straight away and shows the stock toast', async () => {
    const wrapper = await mountDialog();
    dispatch.mockClear();

    await agentRows(wrapper)[1].trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('assignAgent', {
      conversationId: 42,
      agentId: 3,
      assigneeType: 'User',
    });
    expect(useAlert).toHaveBeenCalledWith('CONVERSATION.CHANGE_AGENT');
  });
});
