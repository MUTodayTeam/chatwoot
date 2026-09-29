import { nextTick, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../vitest.i18n';
import ConversationEndBar from '../ConversationEndBar.vue';

withFullI18n();

const dispatch = vi.fn();
const getters = {
  'liveChatRules/getLiveChatRules': ref([
    { id: 1, projectId: null, autoCloseHours: 48 },
    { id: 2, projectId: 7, autoCloseHours: 2 },
  ]),
  'projects/getProjects': ref([{ id: 7, name: 'Checkin+', inboxIds: [3] }]),
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key => getters[key],
}));

const NOW = 1_800_000_000;

const mountBar = chat =>
  mount(ConversationEndBar, {
    props: {
      chat: {
        id: 12,
        inbox_id: 3,
        status_changed_at: NOW - 30 * 60,
        case: { id: 4, display: '#CK-858', severity: 'p3' },
        ...chat,
      },
    },
  });

describe('ConversationEndBar', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW * 1000);
    dispatch.mockReset();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('counts a solved conversation down to the close on its project rule', () => {
    const wrapper = mountBar({ status: 'resolved' });

    expect(wrapper.text()).toContain('Solved · Other');
    expect(wrapper.text()).toContain('→ Closed in 01:30:00');
    expect(wrapper.text()).toContain(
      'If the customer writes back, case #CK-858 reopens with its full history'
    );
  });

  it('keeps counting every second', async () => {
    const wrapper = mountBar({ status: 'resolved' });

    vi.advanceTimersByTime(5000);
    await nextTick();

    expect(wrapper.text()).toContain('→ Closed in 01:29:55');
  });

  it('uses the account default rule for an inbox outside every project', () => {
    const wrapper = mountBar({ status: 'resolved', inbox_id: 99 });

    expect(wrapper.text()).toContain('→ Closed in 47:30:00');
  });

  it('counts down from updated_at when the conversation has no status_changed_at, as the sweep does', () => {
    const wrapper = mountBar({
      status: 'resolved',
      status_changed_at: 0,
      updated_at: NOW - 60 * 60 + 0.25,
    });

    expect(wrapper.text()).toContain('→ Closed in 01:00:00');
  });

  it('shows a closed conversation without a countdown or a Reopen button', () => {
    const wrapper = mountBar({ status: 'closed' });

    expect(wrapper.text()).toContain('Closed · Other');
    expect(wrapper.text()).not.toContain('Closed in');
    expect(wrapper.text()).toContain('case #CK-858 reopens');
    expect(wrapper.find('button').exists()).toBe(false);
  });

  it('talks about the conversation when it has no case', () => {
    const wrapper = mountBar({ status: 'closed', case: null });

    expect(wrapper.text()).toContain(
      'If the customer writes back, the conversation reopens with its full history'
    );
  });

  it('reopens a solved conversation through toggle_status', async () => {
    dispatch.mockResolvedValue();
    const wrapper = mountBar({ status: 'resolved' });

    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('toggleStatus', {
      conversationId: 12,
      status: 'open',
    });
  });
});
