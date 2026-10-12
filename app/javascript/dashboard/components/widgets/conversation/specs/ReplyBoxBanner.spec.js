import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import ReplyBoxBanner from '../ReplyBoxBanner.vue';
import BotModeBanner from 'dashboard/components-next/Conversation/BotModeBanner.vue';
import ConversationApi from 'dashboard/api/inbox/conversation';

withFullI18n();

const dispatch = vi.fn();
const commit = vi.fn();
const currentChat = ref({});
const currentUser = ref({ id: 7, name: 'Jason', avatar_url: '' });

vi.mock('vuex', () => ({ useStore: () => ({ dispatch, commit }) }));
vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { assignAgent: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => (key === 'getCurrentUser' ? currentUser : currentChat),
}));

const mountBanner = chat => {
  currentChat.value = { id: 12, meta: {}, ...chat };
  return mount(ReplyBoxBanner, { global: { stubs: { Banner: true } } });
};

const clickTakeOver = async wrapper => {
  await wrapper.findComponent(BotModeBanner).find('button').trigger('click');
  await flushPromises();
};

describe('ReplyBoxBanner', () => {
  beforeEach(() => {
    dispatch.mockReset();
    commit.mockReset();
    ConversationApi.assignAgent.mockReset();
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
    expect(wrapper.text()).toContain(
      'This chat is in Bot mode — take it over as an agent'
    );
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

  it.each([
    ['an agent bot', 3, 'AgentBot'],
    ['a Captain assistant', 3, 'Captain::Assistant'],
    ['a Captain assistant whose id matches the agent', 7, 'Captain::Assistant'],
  ])(
    'takes the chat over from %s by assigning it to the agent and opening it',
    async (_, assigneeId, type) => {
      ConversationApi.assignAgent.mockResolvedValue({
        data: currentUser.value,
      });
      const wrapper = mountBanner({
        status: 'pending',
        meta: {
          assignee: { id: assigneeId, name: 'Bot' },
          assignee_type: type,
        },
      });

      await clickTakeOver(wrapper);

      expect(ConversationApi.assignAgent).toHaveBeenCalledWith({
        conversationId: 12,
        agentId: 7,
        assigneeType: 'User',
      });
      expect(dispatch).toHaveBeenCalledWith('setCurrentChatAssignee', {
        conversationId: 12,
        assignee: currentUser.value,
        assigneeType: 'User',
      });
      expect(commit).toHaveBeenCalledWith('CHANGE_CONVERSATION_STATUS', {
        conversationId: 12,
        status: 'open',
        snoozedUntil: null,
      });
    }
  );

  it('leaves the chat as it was when the takeover assignment fails', async () => {
    ConversationApi.assignAgent.mockRejectedValue(new Error('Failed'));
    const wrapper = mountBanner({
      status: 'pending',
      meta: {
        assignee: { id: 3, name: 'Captain' },
        assignee_type: 'Captain::Assistant',
      },
    });

    await clickTakeOver(wrapper);

    expect(ConversationApi.assignAgent).toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
    expect(commit).not.toHaveBeenCalled();
    expect(wrapper.findComponent(BotModeBanner).exists()).toBe(true);
  });
});
