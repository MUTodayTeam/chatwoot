import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import StatusDropdown from '../StatusDropdown.vue';

const dispatch = vi.fn();
const currentChat = ref({});

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: () => currentChat,
}));
vi.mock('dashboard/composables/emitter', () => ({ useEmitter: vi.fn() }));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));
vi.mock('dashboard/composables/useConversationRequiredAttributes', () => ({
  useConversationRequiredAttributes: () => ({
    checkMissingAttributes: () => ({ hasMissing: false, missing: [] }),
  }),
}));

const STATUS_KEY = 'CONVERSATION.STATUS_DROPDOWN.STATUSES';

const mountDropdown = async chat => {
  currentChat.value = {
    id: 7,
    snoozed_until: null,
    meta: {},
    custom_attributes: {},
    ...chat,
  };
  const wrapper = mount(StatusDropdown, {
    global: {
      directives: { onClickaway: {} },
      stubs: { ConversationResolveAttributesModal: true },
    },
  });
  await wrapper.find('button').trigger('click');
  return wrapper;
};

// The first button is the trigger, which carries the current status as its label.
const menuItem = (wrapper, value) =>
  wrapper
    .findAll('button')
    .slice(1)
    .find(button => button.text() === `${STATUS_KEY}.${value}`);

describe('StatusDropdown', () => {
  beforeEach(() => {
    dispatch.mockReset();
    useAlert.mockReset();
  });

  it('labels the button with the lifecycle status', async () => {
    const wrapper = await mountDropdown({ status: 'snoozed' });

    expect(wrapper.find('button').text()).toBe(`${STATUS_KEY}.on_hold`);
  });

  it('enables Closed only on a resolved conversation', async () => {
    const open = await mountDropdown({ status: 'open' });
    expect(menuItem(open, 'closed').attributes('disabled')).toBeDefined();

    const resolved = await mountDropdown({ status: 'resolved' });
    expect(menuItem(resolved, 'closed').attributes('disabled')).toBeUndefined();
  });

  it('closes a resolved conversation through toggle_status', async () => {
    dispatch.mockResolvedValue();
    const wrapper = await mountDropdown({ status: 'resolved' });

    await menuItem(wrapper, 'closed').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 7,
      status: 'closed',
      snoozedUntil: null,
      customAttributes: null,
    });
    expect(useAlert).toHaveBeenCalledWith('CONVERSATION.CHANGE_STATUS');
  });

  it('puts a conversation on hold as snoozed with no reopen time', async () => {
    dispatch.mockResolvedValue();
    const wrapper = await mountDropdown({ status: 'open' });

    await menuItem(wrapper, 'on_hold').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'toggleStatus',
      expect.objectContaining({ status: 'snoozed', snoozedUntil: null })
    );
  });

  it('resolves when Solved is picked', async () => {
    dispatch.mockResolvedValue();
    const wrapper = await mountDropdown({ status: 'open' });

    await menuItem(wrapper, 'solved').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'toggleStatus',
      expect.objectContaining({ status: 'resolved' })
    );
  });

  it('alerts with the reason when the server refuses the change', async () => {
    dispatch.mockRejectedValue(
      new Error('Status can only be closed after the conversation is resolved')
    );
    const wrapper = await mountDropdown({ status: 'resolved' });

    await menuItem(wrapper, 'closed').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'Status can only be closed after the conversation is resolved'
    );
  });

  it('shows Bot as a read-only entry while a bot holds the conversation', async () => {
    const wrapper = await mountDropdown({
      status: 'pending',
      meta: { assignee_type: 'AgentBot' },
    });

    expect(wrapper.find('button').text()).toBe(`${STATUS_KEY}.bot`);
    expect(menuItem(wrapper, 'bot').attributes('disabled')).toBeDefined();
    expect(menuItem(wrapper, 'open').attributes('disabled')).toBeUndefined();
  });

  it('offers only Open on a closed conversation and no timed snooze', async () => {
    const wrapper = await mountDropdown({ status: 'closed' });

    const enabled = ['open', 'pending', 'on_hold', 'solved', 'closed'].filter(
      value => menuItem(wrapper, value).attributes('disabled') === undefined
    );
    expect(enabled).toEqual(['open']);
    expect(wrapper.text()).not.toContain(
      'CONVERSATION.STATUS_DROPDOWN.SNOOZE_UNTIL'
    );
  });

  it('keeps the timed snooze on open conversations', async () => {
    const wrapper = await mountDropdown({ status: 'open' });

    expect(wrapper.text()).toContain(
      'CONVERSATION.STATUS_DROPDOWN.SNOOZE_UNTIL'
    );
  });
});
