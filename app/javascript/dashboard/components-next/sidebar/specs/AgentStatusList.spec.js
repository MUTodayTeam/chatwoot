import { ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import { provideDropdownContext } from 'next/dropdown-menu/base/provider.js';
import AgentStatusList from '../AgentStatusList.vue';

const dispatch = vi.fn();

const getters = {
  'agentStatus/getAgentStatus': ref('lunch'),
  'agentStatus/getToday': ref({
    ready: 5430,
    busy: 60,
    mini_break: 0,
    lunch: 3600,
    briefing: 0,
    rest_room: 120,
    online_total: 9210,
  }),
  'agentStatus/getFetchedAt': ref(Date.now()),
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => getters[name],
  useStore: () => ({ dispatch }),
}));

// The menu rows need the dropdown a real menu mounts them in
const closeMenu = vi.fn();
const Host = {
  components: { AgentStatusList },
  setup() {
    provideDropdownContext({
      isOpen: ref(true),
      toggle: () => {},
      closeMenu,
    });
  },
  template: '<ul><AgentStatusList /></ul>',
};

const STATUS_LABELS = [
  'READY',
  'BUSY',
  'MINI_BREAK',
  'LUNCH',
  'BRIEFING',
  'REST_ROOM',
  'OFFLINE',
].map(status => `SIDEBAR_ITEMS.AGENT_STATUS.STATUS.${status}`);

const statusButtons = wrapper =>
  wrapper.findAll('button').filter(button => button.find('.size-2').exists());

describe('AgentStatusList', () => {
  beforeEach(() => {
    dispatch.mockReset();
    dispatch.mockResolvedValue();
    useAlert.mockReset();
    closeMenu.mockReset();
  });

  it('re-reads the status when the menu opens', () => {
    mount(Host);

    expect(dispatch).toHaveBeenCalledWith('agentStatus/fetch');
  });

  it('lists the seven statuses in order and checks the current one', () => {
    const wrapper = mount(Host);
    const buttons = statusButtons(wrapper);

    expect(buttons).toHaveLength(7);
    expect(buttons.map(button => button.find('.truncate').text())).toEqual(
      STATUS_LABELS
    );
    expect(
      buttons.filter(button => button.find('.i-lucide-check').exists())
    ).toHaveLength(1);
    expect(buttons[3].find('.i-lucide-check').exists()).toBe(true);
  });

  it("sums today's time per status, with the open one still counting, and the online total", () => {
    const wrapper = mount(Host);
    const durations = wrapper
      .findAll('.tabular-nums')
      .map(duration => duration.text());

    // ready, busy, mini break, lunch, briefing, rest room, offline (none), then the online total
    expect(durations).toEqual([
      '1:30',
      '0:01',
      '0:00',
      '1:00',
      '0:00',
      '0:02',
      '',
      '2:33',
    ]);
    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.ONLINE_TOTAL');
  });

  it('sets the picked status', async () => {
    const wrapper = mount(Host);
    dispatch.mockClear();

    await statusButtons(wrapper)[0].trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('agentStatus/set', {
      status: 'ready',
    });
    expect(useAlert).not.toHaveBeenCalled();
    expect(closeMenu).toHaveBeenCalled();
  });

  it('alerts when the status could not be set', async () => {
    const wrapper = mount(Host);
    dispatch.mockRejectedValue(new Error('nope'));

    await statusButtons(wrapper)[0].trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'
    );
  });
});
