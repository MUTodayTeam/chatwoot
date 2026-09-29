import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import CannedResponse from '../CannedResponse.vue';
import CaretAnchoredPicker from 'dashboard/components-next/preview-picker/CaretAnchoredPicker.vue';

withFullI18n();

const dispatch = vi.fn();
const getters = {
  getCannedResponses: ref([
    { id: 1, short_code: 'thanks', content: 'Thanks', project_id: null },
    { id: 2, short_code: 'checkin', content: 'Checkin+ hours', project_id: 7 },
    { id: 3, short_code: 'share', content: 'Share hours', project_id: 8 },
  ]),
  getUIFlags: ref({ fetchingList: false }),
  'projects/getProjects': ref([
    { id: 7, name: 'Checkin+', inboxIds: [3] },
    { id: 8, name: 'Share', inboxIds: [4] },
  ]),
};

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
  useMapGetter: key => getters[key],
}));

const shortcutsFor = props => {
  const wrapper = mount(CannedResponse, {
    props,
    global: {
      stubs: { CaretAnchoredPicker: true },
      directives: { dompurifyHtml: {} },
    },
  });
  return wrapper
    .findComponent(CaretAnchoredPicker)
    .props('items')
    .map(item => item.label);
};

describe('CannedResponse', () => {
  beforeEach(() => dispatch.mockReset());

  it("offers the conversation's project responses and the shared ones", () => {
    expect(shortcutsFor({ inboxId: 3 })).toEqual(['/thanks', '/checkin']);
    expect(dispatch).toHaveBeenCalledWith('getCannedResponse');
  });

  it('offers only the shared responses in an inbox outside every project', () => {
    expect(shortcutsFor({ inboxId: 99 })).toEqual(['/thanks']);
  });

  it('offers every response in an editor outside a conversation', () => {
    expect(shortcutsFor({})).toEqual(['/thanks', '/checkin', '/share']);
  });
});
