import { mount, flushPromises } from '@vue/test-utils';
import CaseCategoriesAPI from 'dashboard/api/caseCategories';
import SelectCategoryDialog from '../SelectCategoryDialog.vue';

const push = vi.fn();

vi.mock('dashboard/api/caseCategories', () => ({
  default: { get: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: { value: true } }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: 1 }),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));

const categories = [
  {
    id: 1,
    inquiry_type: 'info',
    c1: 'ทั่วไป',
    c2: 'ทักทาย',
    c3: 'Greeting',
    sla_respond_minutes: 5,
    sla_resolve_minutes: null,
  },
  {
    id: 2,
    inquiry_type: 'problem',
    c1: 'Booking',
    c2: 'Overbooking',
    c3: 'Same room',
    sla_respond_minutes: 15,
    sla_resolve_minutes: 240,
  },
];

const DialogStub = {
  name: 'Dialog',
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /><slot name="footer" /></div>',
};

const mountDialog = async ({ payload = categories, current = null } = {}) => {
  CaseCategoriesAPI.get.mockResolvedValue({ data: { payload } });
  const wrapper = mount(SelectCategoryDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open(current);
  await flushPromises();
  return wrapper;
};

const rows = wrapper => wrapper.findAll('tbody tr');
const solveButton = wrapper =>
  wrapper
    .findAll('button')
    .find(
      button =>
        button.text().startsWith('CASE_CATEGORIES.SOLVE.S') ||
        button.text() === 'CASE_CATEGORIES.SOLVE.CHOOSE_FIRST'
    );

describe('SelectCategoryDialog', () => {
  it('lists every category and keeps Solved disabled until one is picked', async () => {
    const wrapper = await mountDialog();

    expect(rows(wrapper)).toHaveLength(2);
    expect(solveButton(wrapper).attributes('disabled')).toBeDefined();
    expect(wrapper.emitted('solve')).toBeUndefined();
  });

  it('filters by inquiry type tab and by search on any level', async () => {
    const wrapper = await mountDialog();

    const problemTab = wrapper
      .findAll('button')
      .find(button =>
        button.text().startsWith('CASE_CATEGORIES.INQUIRY_TYPES.problem')
      );
    await problemTab.trigger('click');
    expect(rows(wrapper).map(row => row.text())).toEqual([
      expect.stringContaining('Same room'),
    ]);

    const allTab = wrapper
      .findAll('button')
      .find(button =>
        button.text().startsWith('CASE_CATEGORIES.INQUIRY_TYPES.all')
      );
    await allTab.trigger('click');
    await wrapper.find('input[type="text"]').setValue('ทักทาย');
    expect(rows(wrapper).map(row => row.text())).toEqual([
      expect.stringContaining('Greeting'),
    ]);
  });

  it('highlights the one row picked and solves with it, the summary and the survey choice', async () => {
    const wrapper = await mountDialog();

    await rows(wrapper)[1].trigger('click');
    await rows(wrapper)[0].trigger('click');
    expect(rows(wrapper)[0].classes()).toContain('!bg-n-brand/10');
    expect(rows(wrapper)[1].classes()).not.toContain('!bg-n-brand/10');

    const [, summaryInput] = wrapper.findAll('input[type="text"]');
    await summaryInput.setValue('  ส่งคำอวยพรแล้ว  ');
    await wrapper.find('input[type="checkbox"]').setValue(false);
    await solveButton(wrapper).trigger('click');

    expect(wrapper.emitted('solve')).toEqual([
      [{ caseCategoryId: 1, summary: 'ส่งคำอวยพรแล้ว', sendSurvey: false }],
    ]);
  });

  it('preselects the category the case was solved under before', async () => {
    const wrapper = await mountDialog({ current: 2 });

    expect(rows(wrapper)[1].classes()).toContain('!bg-n-brand/10');
    expect(solveButton(wrapper).attributes('disabled')).toBeUndefined();
  });

  it('solves as Other when the account has no categories yet', async () => {
    const wrapper = await mountDialog({ payload: [] });

    await solveButton(wrapper).trigger('click');

    expect(wrapper.emitted('solve')).toEqual([
      [{ caseCategoryId: null, summary: '', sendSurvey: true }],
    ]);
  });

  it('links administrators to the Categories settings', async () => {
    const wrapper = await mountDialog();

    await wrapper
      .findAll('button')
      .find(button => button.text() === 'CASE_CATEGORIES.SOLVE.MANAGE')
      .trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'case_categories_index',
      params: { accountId: 1 },
    });
  });
});
