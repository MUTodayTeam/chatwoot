import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import ListRowTime from '../ListRowTime.vue';

withFullI18n();

const MINUTE = 60 * 1000;

describe('ListRowTime', () => {
  let tooltip;

  const mountTime = props =>
    mount(ListRowTime, {
      props,
      global: {
        directives: {
          tooltip: {
            mounted: (_, binding) => {
              tooltip = binding.value;
            },
            updated: (_, binding) => {
              tooltip = binding.value;
            },
          },
        },
      },
    });

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 8, 29, 23, 59, 30));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('turns the time into a date once the day changes with the list open', async () => {
    const lastActivity = new Date(2026, 8, 29, 9, 5).getTime() / 1000;
    const wrapper = mountTime({ lastActivityTimestamp: lastActivity });

    expect(wrapper.text()).toBe('09:05');

    await vi.advanceTimersByTimeAsync(MINUTE);
    await nextTick();

    expect(wrapper.text()).toBe('29/09/26');
  });

  it('shows the exact created and last activity times on hover', () => {
    const createdAt = new Date(2026, 8, 20, 8, 0).getTime() / 1000;
    const lastActivity = new Date(2026, 8, 29, 9, 5).getTime() / 1000;
    mountTime({
      lastActivityTimestamp: lastActivity,
      createdAtTimestamp: createdAt,
    });

    expect(tooltip.content).toMatch(/^Created at: .*2026.*\nLast activity: /);
    expect(tooltip.content).toContain('Sep 29, 2026');
  });
});
