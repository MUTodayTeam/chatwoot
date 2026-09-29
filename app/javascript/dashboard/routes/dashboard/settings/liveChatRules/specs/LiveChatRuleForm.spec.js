import { mount, flushPromises } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import LiveChatRuleForm from '../LiveChatRuleForm.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store');

const WootInput = {
  props: ['modelValue', 'label'],
  emits: ['update:modelValue'],
  template:
    '<input :data-label="label" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
};

const NextInput = {
  props: ['modelValue', 'label'],
  emits: ['update:modelValue'],
  template:
    '<input :data-label="label" :value="modelValue" @input="$emit(\'update:modelValue\', Number($event.target.value))" />',
};

const dispatch = vi.fn();
let projects;
let teams;

const mountForm = rule =>
  mount(LiveChatRuleForm, {
    props: { rule },
    global: {
      mocks: { $t: key => key },
      stubs: {
        WootModalHeader: true,
        WootInput,
        Input: NextInput,
        NextButton: { template: '<button type="submit" />' },
      },
    },
  });

const input = (wrapper, label) =>
  wrapper.find(`input[data-label="LIVE_CHAT_RULES.FORM.${label}.LABEL"]`);

describe('LiveChatRuleForm', () => {
  beforeEach(() => {
    dispatch.mockReset();
    useStore.mockReturnValue({ dispatch });
    projects = ref([]);
    teams = ref([{ id: 7, name: 'CRM' }]);
    const getters = {
      'projects/getProjects': projects,
      'teams/getTeams': teams,
      'liveChatRules/getLiveChatRules': ref([]),
      'liveChatRules/getUIFlags': ref({}),
    };
    useMapGetter.mockImplementation(getter => getters[getter]);
  });

  it('prefills the lifecycle settings of the rule', async () => {
    const wrapper = mountForm({
      id: 1,
      projectId: null,
      waitingTimeMinutes: 15,
      autoSolveHours: 12,
      autoCloseHours: 36,
    });
    await flushPromises();

    expect(input(wrapper, 'WAITING_TIME').element.value).toBe('15');
    expect(input(wrapper, 'AUTO_SOLVE').element.value).toBe('12');
    expect(input(wrapper, 'AUTO_CLOSE').element.value).toBe('36');
    expect(input(wrapper, 'CHAT_LIMIT').element.value).toBe('10');
  });

  it('sends the lifecycle settings when saving', async () => {
    const wrapper = mountForm({ id: 1, projectId: null });

    await input(wrapper, 'AUTO_SOLVE').setValue('6');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('liveChatRules/update', {
      id: 1,
      projectId: null,
      replyTimeoutMinutes: 60,
      extensionMinutes: 60,
      waitingTimeMinutes: 60,
      autoSolveHours: 6,
      autoCloseHours: 48,
      chatLimit: 10,
      transferTeamId: null,
      assistedWeight: 0.5,
      transferPenalty: 0.2,
    });
  });

  it('sends the transfer team and the productivity weights of the account default', async () => {
    const wrapper = mountForm({ id: 1, projectId: null, assistedWeight: 0.5 });
    await flushPromises();

    await wrapper.find('select').setValue(7);
    await input(wrapper, 'ASSISTED_WEIGHT').setValue('0.75');
    await input(wrapper, 'TRANSFER_PENALTY').setValue('0.1');
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith(
      'liveChatRules/update',
      expect.objectContaining({
        transferTeamId: 7,
        assistedWeight: 0.75,
        transferPenalty: 0.1,
      })
    );
  });

  it('leaves the weights to the account default on a project override', async () => {
    projects.value = [{ id: 3, name: 'Checkin+' }];
    const wrapper = mountForm({ id: 2, projectId: 3, transferTeamId: 7 });
    await flushPromises();

    expect(input(wrapper, 'ASSISTED_WEIGHT').exists()).toBe(false);
    await wrapper.find('form').trigger('submit');
    await flushPromises();

    const [, payload] = dispatch.mock.calls.find(
      ([action]) => action === 'liveChatRules/update'
    );
    expect(payload).toMatchObject({ projectId: 3, transferTeamId: 7 });
    expect(payload).not.toHaveProperty('assistedWeight');
  });
});
