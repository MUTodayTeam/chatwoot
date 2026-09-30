import { flushPromises, mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../vitest.i18n';
import CasesAPI from 'dashboard/api/cases';
import CaseEditDialog from '../CaseEditDialog.vue';

withFullI18n();

vi.mock('dashboard/api/cases', () => ({
  default: { show: vi.fn(), update: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: [{ id: 3, name: 'Support' }] }),
}));

const DialogStub = {
  name: 'Dialog',
  props: ['disableConfirmButton'],
  emits: ['confirm'],
  methods: { open: vi.fn(), close: vi.fn() },
  template: '<div><slot /></div>',
};

const mountDialog = async () => {
  CasesAPI.show.mockResolvedValue({
    data: {
      display: '#CK-1',
      subject: 'Cannot check in',
      severity: 'p4',
      team: null,
    },
  });
  const wrapper = mount(CaseEditDialog, {
    global: { stubs: { Dialog: DialogStub } },
  });
  wrapper.vm.open(7);
  await flushPromises();
  return wrapper;
};

describe('CaseEditDialog', () => {
  beforeEach(() => {
    CasesAPI.show.mockReset();
    CasesAPI.update.mockReset();
  });

  it('loads the case and saves the edited subject, severity and team', async () => {
    CasesAPI.update.mockResolvedValue({});
    const wrapper = await mountDialog();

    expect(wrapper.find('input').element.value).toBe('Cannot check in');

    await wrapper.find('input').setValue('  Refund  ');
    const [severity, team] = wrapper.findAll('select');
    await severity.setValue('p1');
    await team.setValue('3');
    wrapper.findComponent({ name: 'Dialog' }).vm.$emit('confirm');
    await flushPromises();

    expect(CasesAPI.show).toHaveBeenCalledWith(7);
    expect(CasesAPI.update).toHaveBeenCalledWith(7, {
      subject: 'Refund',
      severity: 'p1',
      team_id: 3,
    });
    expect(wrapper.emitted('updated')).toHaveLength(1);
  });

  it('does not save a blank subject', async () => {
    const wrapper = await mountDialog();

    await wrapper.find('input').setValue('   ');
    wrapper.findComponent({ name: 'Dialog' }).vm.$emit('confirm');
    await flushPromises();

    expect(CasesAPI.update).not.toHaveBeenCalled();
  });
});
