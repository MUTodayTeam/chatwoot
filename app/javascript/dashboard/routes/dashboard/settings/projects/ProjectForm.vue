<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, maxLength, helpers } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { getRandomColor } from 'dashboard/helper/labelColor';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const props = defineProps({
  project: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['close']);

// Matches Project's code validation: the prefix of a case number, as in CK-858
const CODE_MAX_LENGTH = 10;
const CODE_FORMAT = /^[A-Za-z0-9]*$/;

const { t } = useI18n();
const store = useStore();

const isEditing = computed(() => Boolean(props.project?.id));

const name = ref('');
const code = ref('');
const description = ref('');
const color = ref('#000000');
const selectedInboxIds = ref([]);
const selectedTeamIds = ref([]);
const logo = ref(null);
const logoUrl = ref('');

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = useMapGetter('teams/getTeams');
const teamOptions = computed(() =>
  teams.value.map(team => ({ value: team.id, label: team.name }))
);
const uiFlags = useMapGetter('projects/getUIFlags');

const rules = {
  name: { required, minLength: minLength(1) },
  code: {
    maxLength: maxLength(CODE_MAX_LENGTH),
    format: helpers.regex(CODE_FORMAT),
  },
};
const v$ = useVuelidate(rules, { name, code });

const nameErrorMessage = computed(() => {
  if (!v$.value.name.$error) return '';
  return t('PROJECT_MGMT.FORM.NAME.ERROR');
});

const codeErrorMessage = computed(() => {
  if (!v$.value.code.$error) return '';
  return t('PROJECT_MGMT.FORM.CODE.ERROR');
});

const onLogoUpload = ({ file, url }) => {
  logo.value = file;
  logoUrl.value = url;
};

// On a saved project the logo lives on the server, so removing it is a request
// of its own; on an unsaved one there is nothing to purge yet.
const onLogoDelete = async () => {
  if (isEditing.value && props.project.avatarUrl) {
    try {
      await store.dispatch('projects/deleteLogo', props.project.id);
    } catch (error) {
      useAlert(error?.message || t('PROJECT_MGMT.FORM.API.ERROR_MESSAGE'));
      return;
    }
  }
  logo.value = null;
  logoUrl.value = '';
};

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
  store.dispatch('teams/get');

  if (isEditing.value) {
    name.value = props.project.name;
    code.value = props.project.code ?? '';
    description.value = props.project.description ?? '';
    color.value = props.project.color || getRandomColor();
    selectedInboxIds.value = [...(props.project.inboxIds ?? [])];
    selectedTeamIds.value = [...(props.project.teamIds ?? [])];
    logoUrl.value = props.project.avatarUrl ?? '';
  } else {
    color.value = getRandomColor();
  }
});

const onSubmit = async () => {
  const payload = {
    name: name.value,
    code: code.value.trim().toUpperCase(),
    description: description.value,
    color: color.value,
    inboxIds: selectedInboxIds.value,
    teamIds: selectedTeamIds.value,
    logo: logo.value,
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
        v-model="code"
        :class="{ error: v$.code.$error }"
        class="w-full"
        :label="$t('PROJECT_MGMT.FORM.CODE.LABEL')"
        :placeholder="$t('PROJECT_MGMT.FORM.CODE.PLACEHOLDER')"
        :help-text="$t('PROJECT_MGMT.FORM.CODE.HELP')"
        :error="codeErrorMessage"
        @input="v$.code.$touch"
        @blur="v$.code.$touch"
      />

      <woot-input
        v-model="description"
        class="w-full"
        :label="$t('PROJECT_MGMT.FORM.DESCRIPTION.LABEL')"
        :placeholder="$t('PROJECT_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
      />

      <div class="w-full mb-2">
        <label class="block mb-1">
          {{ $t('PROJECT_MGMT.FORM.LOGO.LABEL') }}
        </label>
        <p class="mt-0 mb-2 text-sm text-n-slate-11">
          {{ $t('PROJECT_MGMT.FORM.LOGO.HELP') }}
        </p>
        <Avatar
          :src="logoUrl"
          :name="name || $t('PROJECT_MGMT.FORM.LOGO.LABEL')"
          :size="56"
          allow-upload
          @upload="onLogoUpload"
          @delete="onLogoDelete"
        />
      </div>

      <div class="w-full">
        <label>
          {{ $t('PROJECT_MGMT.FORM.COLOR.LABEL') }}
          <woot-color-picker v-model="color" />
        </label>
      </div>

      <div class="w-full mt-2">
        <label class="block mb-1">
          {{ $t('PROJECT_MGMT.FORM.TEAMS.LABEL') }}
        </label>
        <TagMultiSelectComboBox
          v-model="selectedTeamIds"
          :options="teamOptions"
          :placeholder="$t('PROJECT_MGMT.FORM.TEAMS.PLACEHOLDER')"
          :search-placeholder="$t('PROJECT_MGMT.FORM.TEAMS.SEARCH_PLACEHOLDER')"
          :empty-state="$t('PROJECT_MGMT.FORM.TEAMS.EMPTY')"
        />
        <!-- Rendered here rather than as the combobox message, which stays on one line and
             widened the form past the modal -->
        <p class="mt-2 mb-0 text-sm text-n-slate-11">
          {{ $t('PROJECT_MGMT.FORM.TEAMS.HELP') }}
        </p>
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
