import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';
import StatusDropdown from '../StatusDropdown.vue';

const dispatch = vi.fn();
const currentChat = ref({});
const missingAttributes = ref([]);
const dialogOpen = vi.fn();
const dialogClose = vi.fn();
const attributesModalOpen = vi.fn();

const SelectCategoryDialogStub = {
  name: 'SelectCategoryDialog',
  props: { isLoading: Boolean },
  emits: ['solve'],
  methods: { open: dialogOpen, close: dialogClose },
  template: '<div />',
};
const ResolveAttributesModalStub = {
  name: 'ConversationResolveAttributesModal',
  emits: ['submit'],
  methods: { open: attributesModalOpen },
  template: '<div />',
};

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
    checkMissingAttributes: () => ({
      hasMissing: missingAttributes.value.length > 0,
      missing: missingAttributes.value,
    }),
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
      stubs: {
        ConversationResolveAttributesModal: ResolveAttributesModalStub,
        SelectCategoryDialog: SelectCategoryDialogStub,
      },
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

// The handlers the component registered for a shortcut and a command bar event
const shortcut = keys => useKeyboardEvents.mock.lastCall[0][keys].action;
const commandHandler = event =>
  useEmitter.mock.calls.findLast(([name]) => name === event)[1];

describe('StatusDropdown', () => {
  beforeEach(() => {
    dispatch.mockReset();
    useAlert.mockReset();
    dialogOpen.mockReset();
    dialogClose.mockReset();
    attributesModalOpen.mockReset();
    missingAttributes.value = [];
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

  it('asks for the category when Solved is picked, preselecting the case one', async () => {
    const wrapper = await mountDropdown({
      status: 'open',
      case: { id: 3, case_category_id: 11 },
    });

    await menuItem(wrapper, 'solved').trigger('click');
    await flushPromises();

    expect(dialogOpen).toHaveBeenCalledWith(11);
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('solves with the category, summary and survey choice from the dialog', async () => {
    dispatch.mockResolvedValue();
    const wrapper = await mountDropdown({ status: 'open' });
    await menuItem(wrapper, 'solved').trigger('click');

    wrapper.findComponent(SelectCategoryDialogStub).vm.$emit('solve', {
      caseCategoryId: 11,
      summary: 'Refunded',
      sendSurvey: false,
    });
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('solveConversation', {
      conversationId: 7,
      caseCategoryId: 11,
      summary: 'Refunded',
      sendSurvey: false,
      customAttributes: null,
    });
    expect(dialogClose).toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('CONVERSATION.CHANGE_STATUS');
  });

  it('keeps the dialog open and alerts when the solve is refused', async () => {
    dispatch.mockRejectedValue(new Error('Conversation is already solved'));
    const wrapper = await mountDropdown({ status: 'open' });
    await menuItem(wrapper, 'solved').trigger('click');

    wrapper
      .findComponent(SelectCategoryDialogStub)
      .vm.$emit('solve', { caseCategoryId: 11, summary: '', sendSurvey: true });
    await flushPromises();

    expect(dialogClose).not.toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('Conversation is already solved');
  });

  it('asks for the required attributes first and saves them with the solve', async () => {
    dispatch.mockResolvedValue();
    missingAttributes.value = [{ attribute_key: 'order_id' }];
    const wrapper = await mountDropdown({ status: 'open' });

    await menuItem(wrapper, 'solved').trigger('click');
    expect(attributesModalOpen).toHaveBeenCalled();
    expect(dialogOpen).not.toHaveBeenCalled();

    const context = attributesModalOpen.mock.calls[0][2];
    wrapper
      .findComponent(ResolveAttributesModalStub)
      .vm.$emit('submit', { attributes: { order_id: 'A1' }, context });
    await flushPromises();
    expect(dialogOpen).toHaveBeenCalled();

    wrapper
      .findComponent(SelectCategoryDialogStub)
      .vm.$emit('solve', { caseCategoryId: 11, summary: '', sendSurvey: true });
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'solveConversation',
      expect.objectContaining({ customAttributes: { order_id: 'A1' } })
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

  it.each(['Alt+KeyE', '$mod+Alt+KeyE'])(
    'asks for the category on %s instead of resolving straight away',
    async keys => {
      await mountDropdown({ status: 'open' });

      shortcut(keys)({ preventDefault: vi.fn() });

      expect(dialogOpen).toHaveBeenCalledWith(null);
      expect(dispatch).not.toHaveBeenCalled();
    }
  );

  it('asks for the category from the command bar', async () => {
    await mountDropdown({ status: 'open' });

    commandHandler(CMD_RESOLVE_CONVERSATION)();

    expect(dialogOpen).toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('does not open the dialog on a conversation already solved', async () => {
    await mountDropdown({ status: 'resolved' });

    shortcut('Alt+KeyE')({ preventDefault: vi.fn() });

    expect(dialogOpen).not.toHaveBeenCalled();
  });

  it.each(['resolved', 'closed'])(
    'reopens a %s conversation through the reopen endpoint',
    async status => {
      dispatch.mockResolvedValue();
      const wrapper = await mountDropdown({ status });

      await menuItem(wrapper, 'open').trigger('click');
      await flushPromises();

      expect(dispatch).toHaveBeenCalledWith('reopenConversation', {
        conversationId: 7,
      });
    }
  );

  it('reopens from the command bar through the reopen endpoint once solved', async () => {
    dispatch.mockResolvedValue();
    await mountDropdown({ status: 'resolved' });

    commandHandler(CMD_REOPEN_CONVERSATION)();
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('reopenConversation', {
      conversationId: 7,
    });
  });

  it('opens a pending conversation with a plain status change', async () => {
    dispatch.mockResolvedValue();
    const wrapper = await mountDropdown({ status: 'pending' });

    await menuItem(wrapper, 'open').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'toggleStatus',
      expect.objectContaining({ status: 'open' })
    );
  });

  it('keeps the timed snooze on open conversations', async () => {
    const wrapper = await mountDropdown({ status: 'open' });

    expect(wrapper.text()).toContain(
      'CONVERSATION.STATUS_DROPDOWN.SNOOZE_UNTIL'
    );
  });
});
