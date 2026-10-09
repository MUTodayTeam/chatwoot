import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import InboxMembersAPI from 'dashboard/api/inboxMembers';
import AddAgent from '../AddAgent.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/inboxMembers', () => ({
  default: { create: vi.fn() },
}));

const INBOXES = [
  { id: 1, name: 'Line - MUToday' },
  { id: 2, name: 'Facebook - MUToday' },
  { id: 3, name: 'Website' },
];
// The projects store camelizes the API payload, so inbox_ids arrives as inboxIds
const PROJECTS = [{ id: 7, name: 'MUToday', inboxIds: [1, 2] }];

const mountAddAgent = createAgent => {
  const store = createStore({
    getters: {
      'agents/getUIFlags': () => ({ isCreating: false }),
      'customRole/getCustomRoles': () => [],
      'inboxes/getInboxes': () => INBOXES,
      'projects/getProjects': () => PROJECTS,
    },
    actions: { 'agents/create': createAgent },
  });
  return mount(AddAgent, {
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      stubs: { 'woot-modal-header': true },
    },
  });
};

const fillAndSubmit = async wrapper => {
  await wrapper.find('input[type="text"]').setValue('Bam');
  await wrapper.find('input[type="email"]').setValue('bam@example.com');
  await wrapper.find('form').trigger('submit');
  await flushPromises();
};

const inboxCheckbox = (wrapper, name) =>
  wrapper
    .findAll('label')
    .find(label => label.text() === name)
    .find('input[type="checkbox"]');

describe('AddAgent inbox picker', () => {
  beforeEach(() => {
    InboxMembersAPI.create.mockReset().mockResolvedValue({});
    useAlert.mockReset();
  });

  it('groups the inboxes by project and ticks all of them to start with', () => {
    const wrapper = mountAddAgent(vi.fn());
    const labels = wrapper.findAll('label').map(label => label.text());

    expect(labels).toEqual(
      expect.arrayContaining([
        'MUToday',
        'Line - MUToday',
        'Facebook - MUToday',
        'AGENT_MGMT.ADD.FORM.INBOXES.NO_PROJECT',
        'Website',
      ])
    );
    INBOXES.forEach(inbox => {
      expect(inboxCheckbox(wrapper, inbox.name).element.checked).toBe(true);
    });
  });

  it('adds the new agent to the ticked inboxes only', async () => {
    const createAgent = vi.fn().mockResolvedValue({ id: 42 });
    const wrapper = mountAddAgent(createAgent);
    await inboxCheckbox(wrapper, 'Website').setValue(false);

    await fillAndSubmit(wrapper);

    expect(createAgent).toHaveBeenCalledTimes(1);
    expect(InboxMembersAPI.create.mock.calls.map(([body]) => body)).toEqual([
      { inbox_id: 1, user_ids: [42] },
      { inbox_id: 2, user_ids: [42] },
    ]);
    expect(useAlert).toHaveBeenCalledWith('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('unticks a whole project with its checkbox', async () => {
    const wrapper = mountAddAgent(vi.fn().mockResolvedValue({ id: 42 }));
    await inboxCheckbox(wrapper, 'MUToday').setValue(false);

    await fillAndSubmit(wrapper);

    expect(InboxMembersAPI.create.mock.calls.map(([body]) => body)).toEqual([
      { inbox_id: 3, user_ids: [42] },
    ]);
  });

  it('names the inboxes the agent could not be added to', async () => {
    InboxMembersAPI.create.mockImplementation(({ inbox_id: inboxId }) =>
      inboxId === 2
        ? Promise.reject(new Error('forbidden'))
        : Promise.resolve({})
    );
    const wrapper = mountAddAgent(vi.fn().mockResolvedValue({ id: 42 }));

    await fillAndSubmit(wrapper);

    expect(useAlert).toHaveBeenCalledWith('AGENT_MGMT.ADD.API.INBOX_ERROR');
    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
