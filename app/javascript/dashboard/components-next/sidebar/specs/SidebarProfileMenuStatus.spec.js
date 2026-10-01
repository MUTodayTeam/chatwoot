import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { provideDropdownContext } from 'next/dropdown-menu/base/provider.js';
import SidebarProfileMenuStatus from '../SidebarProfileMenuStatus.vue';

const dispatch = vi.fn();

const getters = {
  getCurrentAccountId: ref(7),
  getCurrentUserAutoOffline: ref(true),
  'agentStatus/getAgentStatus': ref('lunch'),
  'agentStatus/getToday': ref({}),
  'agentStatus/getFetchedAt': ref(Date.now()),
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: name => getters[name],
  useStore: () => ({ dispatch }),
}));

// The rows need the profile menu a real sidebar mounts them in
const Host = {
  components: { SidebarProfileMenuStatus },
  setup() {
    provideDropdownContext({
      isOpen: ref(true),
      toggle: () => {},
      closeMenu: () => {},
    });
  },
  template: '<SidebarProfileMenuStatus />',
};

// An open dropdown, so its body renders next to the trigger
const OpenDropdown = {
  template: '<div><slot name="trigger" :toggle="() => {}" /><slot /></div>',
};

const mountRow = ({ open = false } = {}) =>
  mount(Host, {
    global: {
      directives: { tooltip: {} },
      stubs: open ? { DropdownContainer: OpenDropdown } : {},
    },
  });

describe('SidebarProfileMenuStatus', () => {
  beforeEach(() => dispatch.mockReset());

  it('shows only the current status until its dropdown opens', () => {
    const wrapper = mountRow();

    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.TITLE');
    expect(wrapper.find('button').text()).toContain(
      'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.LUNCH'
    );
    expect(wrapper.text()).not.toContain(
      'SIDEBAR_ITEMS.AGENT_STATUS.STATUS.READY'
    );
    expect(wrapper.text()).toContain('SIDEBAR.SET_AUTO_OFFLINE.TEXT');
  });

  it('lists every status with its time in the open dropdown', () => {
    const wrapper = mountRow({ open: true });

    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.STATUS.READY');
    expect(wrapper.text()).toContain('SIDEBAR_ITEMS.AGENT_STATUS.ONLINE_TOTAL');
    expect(dispatch).toHaveBeenCalledWith('agentStatus/fetch');
  });
});
