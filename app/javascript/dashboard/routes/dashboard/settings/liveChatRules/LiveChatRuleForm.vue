<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  rule: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const projects = useMapGetter('projects/getProjects');
const rules = useMapGetter('liveChatRules/getLiveChatRules');
const uiFlags = useMapGetter('liveChatRules/getUIFlags');

const projectId = ref(null);
const replyTimeoutMinutes = ref(60);
const extensionMinutes = ref(60);

// The scope of a saved rule is fixed: moving it would silently retarget which
// conversations it governs. Only a brand new rule lets you choose.
const isScopeLocked = computed(() => Boolean(props.rule.id));

const overriddenProjectIds = computed(() =>
  rules.value.filter(rule => rule.projectId).map(rule => rule.projectId)
);

const hasAccountDefault = computed(() =>
  rules.value.some(rule => !rule.projectId)
);

const availableProjects = computed(() =>
  projects.value.filter(
    project =>
      !overriddenProjectIds.value.includes(project.id) ||
      project.id === props.rule.projectId
  )
);

const scopeName = computed(() => {
  if (!props.rule.projectId) return t('LIVE_CHAT_RULES.SCOPE.ACCOUNT');
  const project = projects.value.find(p => p.id === props.rule.projectId);
  return project?.name ?? t('LIVE_CHAT_RULES.SCOPE.ACCOUNT');
});

// Every scope can hold one rule, so a new rule needs a scope that is still free.
const hasSelectableScope = computed(
  () =>
    isScopeLocked.value || !hasAccountDefault.value || Boolean(projectId.value)
);

const isValid = computed(
  () =>
    replyTimeoutMinutes.value > 0 &&
    extensionMinutes.value > 0 &&
    hasSelectableScope.value
);

onMounted(() => {
  replyTimeoutMinutes.value = props.rule.replyTimeoutMinutes ?? 60;
  extensionMinutes.value = props.rule.extensionMinutes ?? 60;

  if (props.rule.projectId) {
    projectId.value = props.rule.projectId;
  } else if (!props.rule.id && hasAccountDefault.value) {
    // The account default is taken, so a new rule can only be a project override.
    projectId.value = availableProjects.value[0]?.id ?? null;
  } else {
    projectId.value = null;
  }
});

const onSubmit = async () => {
  const payload = {
    projectId: projectId.value || null,
    replyTimeoutMinutes: Number(replyTimeoutMinutes.value),
    extensionMinutes: Number(extensionMinutes.value),
  };

  try {
    if (props.rule.id) {
      await store.dispatch('liveChatRules/update', {
        id: props.rule.id,
        ...payload,
      });
    } else {
      await store.dispatch('liveChatRules/create', payload);
    }
    useAlert(t('LIVE_CHAT_RULES.FORM.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(error?.message || t('LIVE_CHAT_RULES.FORM.API.ERROR_MESSAGE'));
  }
};

const isSaving = computed(
  () => uiFlags.value.isCreating || uiFlags.value.isUpdating
);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('LIVE_CHAT_RULES.FORM.TITLE')"
      :header-content="$t('LIVE_CHAT_RULES.FORM.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="onSubmit">
      <div class="w-full">
        <label>
          {{ $t('LIVE_CHAT_RULES.FORM.SCOPE.LABEL') }}
          <p
            v-if="isScopeLocked"
            class="mt-1 mb-0 text-sm font-medium text-n-slate-12"
          >
            {{ scopeName }}
          </p>
          <select v-else v-model="projectId">
            <option v-if="!hasAccountDefault" :value="null">
              {{ $t('LIVE_CHAT_RULES.SCOPE.ACCOUNT') }}
            </option>
            <option
              v-for="project in availableProjects"
              :key="project.id"
              :value="project.id"
            >
              {{ project.name }}
            </option>
          </select>
        </label>
      </div>

      <woot-input
        v-model="replyTimeoutMinutes"
        type="number"
        class="w-full"
        :label="$t('LIVE_CHAT_RULES.FORM.REPLY_TIMEOUT.LABEL')"
        :help-text="$t('LIVE_CHAT_RULES.FORM.REPLY_TIMEOUT.HELP')"
      />

      <woot-input
        v-model="extensionMinutes"
        type="number"
        class="w-full"
        :label="$t('LIVE_CHAT_RULES.FORM.EXTENSION.LABEL')"
        :help-text="$t('LIVE_CHAT_RULES.FORM.EXTENSION.HELP')"
      />

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('LIVE_CHAT_RULES.FORM.CANCEL')"
          @click.prevent="emit('close')"
        />
        <NextButton
          type="submit"
          :label="$t('LIVE_CHAT_RULES.FORM.SAVE')"
          :disabled="!isValid || isSaving"
          :is-loading="isSaving"
        />
      </div>
    </form>
  </div>
</template>
