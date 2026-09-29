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

const dispatch = vi.fn();

const mountForm = rule =>
  mount(LiveChatRuleForm, {
    props: { rule },
    global: {
      mocks: { $t: key => key },
      stubs: {
        WootModalHeader: true,
        WootInput,
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
    const getters = {
      'projects/getProjects': ref([]),
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
    });
  });
});
