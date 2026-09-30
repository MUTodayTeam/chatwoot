import { mount } from '@vue/test-utils';
import HeatmapDateRangeSelector from '../HeatmapDateRangeSelector.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
    locale: { value: 'en' },
  }),
}));

const mountSelector = props =>
  mount(HeatmapDateRangeSelector, {
    props,
    global: { stubs: { Button: true, DropdownMenu: true } },
  });

describe('HeatmapDateRangeSelector', () => {
  it('starts on the last 7 days without a default range', () => {
    const wrapper = mountSelector();

    expect(wrapper.findComponent({ name: 'Button' }).attributes('label')).toBe(
      'REPORT.DATE_RANGE_OPTIONS.LAST_7_DAYS'
    );
    expect(wrapper.emitted('update:daysNum').at(-1)).toEqual([6]);
  });

  it('starts on the given default range', () => {
    const wrapper = mountSelector({ defaultRange: 'last_30_days' });

    expect(wrapper.findComponent({ name: 'Button' }).attributes('label')).toBe(
      'REPORT.DATE_RANGE_OPTIONS.LAST_30_DAYS'
    );
    expect(wrapper.emitted('update:daysNum').at(-1)).toEqual([29]);
  });
});
