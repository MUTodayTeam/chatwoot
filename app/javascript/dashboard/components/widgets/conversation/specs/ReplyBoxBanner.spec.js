import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import ReplyBoxBanner from '../ReplyBoxBanner.vue';
import BotModeBanner from 'dashboard/components-next/Conversation/BotModeBanner.vue';

const dispatch = vi.fn();
const currentChat = ref({});
const currentUser = ref({ id: 7, name: 'Jason', avatar_url: '' });

vi.mock('vuex', () => ({ useStore: () => ({ dispatch }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => (key === 'getCurrentUser' ? currentUser : currentChat),
}));

const mountBanner = chat => {
  currentChat.value = { id: 12, meta: {}, ...chat };
  return mount(ReplyBoxBanner, { global: { stubs: { Banner: true } } });
};

describe('ReplyBoxBanner', () => {
  beforeEach(() => {
    dispatch.mockReset();
  });

  it.each([
    ['an agent bot', 'AgentBot'],
    ['a Captain assistant', 'Captain::Assistant'],
  ])('shows the Bot mode bar while %s holds a pending chat', (_, type) => {
    const wrapper = mountBanner({
      status: 'pending',
      meta: { assignee: { id: 3, name: 'Bot' }, assignee_type: type },
    });

    expect(wrapper.findComponent(BotModeBanner).exists()).toBe(true);
  });

  it.each([
    ['a pending chat without a bot', { status: 'pending' }],
    [
      'an open chat a bot was assigned to',
      { status: 'open', meta: { assignee_type: 'AgentBot' } },
    ],
    ['a solved chat', { status: 'resolved' }],
  ])('hides the Bot mode bar on %s', (_, chat) => {
    expect(mountBanner(chat).findComponent(BotModeBanner).exists()).toBe(false);
  });

  it('takes the chat over by opening it and assigning it to the agent', async () => {
    dispatch.mockResolvedValue();
    const wrapper = mountBanner({
      status: 'pending',
      meta: { assignee: { id: 3, name: 'Bot' }, assignee_type: 'AgentBot' },
    });

    await wrapper.findComponent(BotModeBanner).find('button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 12,
      status: 'open',
    });
    expect(dispatch).toHaveBeenCalledWith('assignAgent', {
      conversationId: 12,
      agentId: 7,
    });
  });
});
