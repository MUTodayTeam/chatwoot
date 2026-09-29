import { mount } from '@vue/test-utils';
import ChatTypeTabs from '../ChatTypeTabs.vue';
import Tabs from '../../ui/Tabs/Tabs.vue';
import TabsItem from '../../ui/Tabs/TabsItem.vue';

vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

const mountTabs = unassignedCount =>
  mount(ChatTypeTabs, {
    props: {
      items: [
        { key: 'me', name: 'Mine', count: 3 },
        { key: 'unassigned', name: 'Unassigned', count: unassignedCount },
        { key: 'all', name: 'All', count: 9 },
      ],
      activeTab: 'me',
    },
    global: { components: { WootTabs: Tabs, WootTabsItem: TabsItem } },
  });

const countBadge = (wrapper, index) =>
  wrapper.findAllComponents(TabsItem)[index].find('a > div');

describe('ChatTypeTabs', () => {
  it('shows the Unassigned count in red', () => {
    const wrapper = mountTabs(2);

    expect(countBadge(wrapper, 1).classes()).toContain('text-n-ruby-11');
    expect(countBadge(wrapper, 2).classes()).not.toContain('text-n-ruby-11');
  });

  it('keeps an empty Unassigned count neutral', () => {
    expect(countBadge(mountTabs(0), 1).classes()).not.toContain(
      'text-n-ruby-11'
    );
  });
});
