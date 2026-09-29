import { mount, flushPromises } from '@vue/test-utils';
import ConversationApi from 'dashboard/api/inbox/conversation';
import TransferDialog from '../TransferDialog.vue';

const dispatch = vi.fn();

vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { getTransfer: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 1 }),
  useStore: () => ({ dispatch }),
}));

const DialogStub = {
  name: 'Dialog',
  props: ['description'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><p class="description">{{ description }}</p><slot /></div>',
};

const transfer = {
  team: { id: 3, name: 'CRM' },
  agents: [{ id: 2, name: 'Poy', availability_status: 'online' }],
  handler: { user_id: 1, started_at: 1_758_000_000 },
};

const mountDialog = async (data = transfer) => {
  ConversationApi.getTransfer.mockResolvedValue({ data });
  const wrapper = mount(TransferDialog, {
    props: { conversationId: 42 },
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open();
  await flushPromises();
  return wrapper;
};

const buttonWithText = (wrapper, text) =>
  wrapper.findAll('button').find(button => button.text().includes(text));

describe('TransferDialog', () => {
  beforeEach(() => {
    dispatch.mockReset();
    vi.useFakeTimers({ now: (1_758_000_000 + 12 * 60) * 1000 });
  });

  afterEach(() => vi.useRealTimers());

  it('lists the transfer team and tells the agent what credit they keep', async () => {
    const wrapper = await mountDialog();

    expect(ConversationApi.getTransfer).toHaveBeenCalledWith(42, {
      signal: expect.any(AbortSignal),
    });
    expect(buttonWithText(wrapper, 'Poy')).toBeDefined();
    expect(wrapper.text()).toContain('CONVERSATION.TRANSFER.CREDIT.SELF');
    expect(
      wrapper
        .findAll('[role="radio"]')
        .map(radio => radio.attributes('aria-checked'))
    ).toEqual(['true', 'false', 'false', 'false']);
  });

  it('transfers to the picked agent with the chosen reason and the note', async () => {
    const wrapper = await mountDialog();

    await buttonWithText(
      wrapper,
      'CONVERSATION.TRANSFER.REASONS.general'
    ).trigger('click');
    await wrapper.find('textarea').setValue('  Wants a refund  ');
    await buttonWithText(wrapper, 'Poy').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('transferConversation', {
      conversationId: 42,
      assigneeId: 2,
      reason: 'general',
      note: 'Wants a refund',
    });
  });

  it('explains that no transfer team is set up', async () => {
    const wrapper = await mountDialog({
      team: null,
      agents: [],
      handler: null,
    });

    expect(wrapper.text()).toContain('CONVERSATION.TRANSFER.NO_TEAM');
    expect(wrapper.text()).toContain('CONVERSATION.TRANSFER.CREDIT.NEW_ONLY');
  });
});
