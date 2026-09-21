<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { getRandomColor } from 'dashboard/helper/labelColor';

import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  project: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => Boolean(props.project?.id));

const name = ref('');
const description = ref('');
const color = ref('#000000');
const selectedInboxIds = ref([]);

const inboxes = useMapGetter('inboxes/getInboxes');
const uiFlags = useMapGetter('projects/getUIFlags');

const rules = { name: { required, minLength: minLength(1) } };
const v$ = useVuelidate(rules, { name });

const nameErrorMessage = computed(() => {
  if (!v$.value.name.$error) return '';
  return t('PROJECT_MGMT.FORM.NAME.ERROR');
});

const toggleInbox = inboxId => {
  const index = selectedInboxIds.value.indexOf(inboxId);
  if (index === -1) {
    selectedInboxIds.value.push(inboxId);
  } else {
    selectedInboxIds.value.splice(index, 1);
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');

  if (isEditing.value) {
    name.value = props.project.name;
    description.value = props.project.description ?? '';
    color.value = props.project.color || getRandomColor();
    selectedInboxIds.value = [...(props.project.inboxIds ?? [])];
  } else {
    color.value = getRandomColor();
  }
});

const onSubmit = async () => {
  const payload = {
    name: name.value,
    description: description.value,
    color: color.value,
    inboxIds: selectedInboxIds.value,
  };

  try {
    if (isEditing.value) {
      await store.dispatch('projects/update', {
        id: props.project.id,
        ...payload,
      });
      useAlert(t('PROJECT_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('projects/create', payload);
      useAlert(t('PROJECT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    }
    emit('close');
  } catch (error) {
    useAlert(error?.message || t('PROJECT_MGMT.FORM.API.ERROR_MESSAGE'));
  }
};

const isSaving = computed(
  () => uiFlags.value.isCreating || uiFlags.value.isUpdating
);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEditing ? $t('PROJECT_MGMT.EDIT.TITLE') : $t('PROJECT_MGMT.ADD.TITLE')
      "
      :header-content="$t('PROJECT_MGMT.FORM.DESC')"
    />
    <form class="flex flex-wrap mx-0" @submit.prevent="onSubmit">
      <woot-input
        v-model="name"
        :class="{ error: v$.name.$error }"
        class="w-full"
        :label="$t('PROJECT_MGMT.FORM.NAME.LABEL')"
        :placeholder="$t('PROJECT_MGMT.FORM.NAME.PLACEHOLDER')"
        :error="nameErrorMessage"
        @input="v$.name.$touch"
        @blur="v$.name.$touch"
      />

      <woot-input
        v-model="description"
        class="w-full"
        :label="$t('PROJECT_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('PROJECT_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
      />

      <div class="w-full">
        <label>
          {{ $t('PROJECT_MGMT.FORM.COLOR.LABEL') }}
          <woot-color-picker v-model="color" />
        </label>
      </div>

      <div class="w-full mt-2">
        <label class="block mb-1">
          {{ $t('PROJECT_MGMT.FORM.INBOXES.LABEL') }}
        </label>
        <p class="mt-0 mb-2 text-sm text-n-slate-11">
          {{ $t('PROJECT_MGMT.FORM.INBOXES.HELP') }}
        </p>
        <p v-if="!inboxes.length" class="text-sm text-n-slate-11">
          {{ $t('PROJECT_MGMT.FORM.INBOXES.EMPTY') }}
        </p>
        <div v-else class="flex flex-col max-h-48 gap-1 overflow-y-auto">
          <label
            v-for="inbox in inboxes"
            :key="inbox.id"
            class="flex items-center gap-2 mb-0 font-normal"
          >
            <input
              type="checkbox"
              :checked="selectedInboxIds.includes(inbox.id)"
              @change="toggleInbox(inbox.id)"
            />
            <span class="text-n-slate-12">{{ inbox.name }}</span>
          </label>
        </div>
      </div>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('PROJECT_MGMT.FORM.CANCEL')"
          @click.prevent="emit('close')"
        />
        <NextButton
          type="submit"
          :label="
            isEditing
              ? $t('PROJECT_MGMT.FORM.SAVE')
              : $t('PROJECT_MGMT.FORM.CREATE')
          "
          :disabled="v$.$invalid || isSaving"
          :is-loading="isSaving"
        />
      </div>
    </form>
  </div>
</template>
