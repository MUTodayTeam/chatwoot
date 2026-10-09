<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import { required, email } from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import InboxMembersAPI from 'dashboard/api/inboxMembers';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const agentName = ref('');
const agentEmail = ref('');
const selectedRoleId = ref('agent');

const rules = {
  agentName: { required },
  agentEmail: { required, email },
  selectedRoleId: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  agentEmail,
  selectedRoleId,
});

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');
const inboxes = useMapGetter('inboxes/getInboxes');
const projects = useMapGetter('projects/getProjects');

// A new agent only gets conversations from the inboxes they are a member of, so they are picked
// here, grouped by project. All are ticked to start with, so nobody is left without chats.
const selectedInboxIds = ref(inboxes.value.map(inbox => inbox.id));

const inboxGroups = computed(() => {
  const grouped = projects.value
    .map(project => ({
      key: `project-${project.id}`,
      label: project.name,
      inboxes: inboxes.value.filter(inbox =>
        (project.inbox_ids || []).includes(inbox.id)
      ),
    }))
    .filter(group => group.inboxes.length);
  const groupedIds = grouped.flatMap(group => group.inboxes.map(i => i.id));
  const rest = inboxes.value.filter(inbox => !groupedIds.includes(inbox.id));
  if (rest.length) {
    grouped.push({
      key: 'no-project',
      label: t('AGENT_MGMT.ADD.FORM.INBOXES.NO_PROJECT'),
      inboxes: rest,
    });
  }
  return grouped;
});

const isSelected = inboxId => selectedInboxIds.value.includes(inboxId);
const toggleInbox = (inboxId, checked) => {
  selectedInboxIds.value = checked
    ? [...new Set([...selectedInboxIds.value, inboxId])]
    : selectedInboxIds.value.filter(id => id !== inboxId);
};
const selectedInGroup = group =>
  group.inboxes.filter(inbox => isSelected(inbox.id)).length;
const toggleGroup = (group, checked) => {
  group.inboxes.forEach(inbox => toggleInbox(inbox.id, checked));
};

const addToInboxes = async agentId => {
  const results = await Promise.allSettled(
    selectedInboxIds.value.map(inboxId =>
      InboxMembersAPI.create({ inbox_id: inboxId, user_ids: [agentId] })
    )
  );
  return selectedInboxIds.value.filter(
    (_, index) => results[index].status === 'rejected'
  );
};

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    const agent = await store.dispatch('agents/create', payload);
    const failedInboxIds = await addToInboxes(agent.id);
    if (failedInboxIds.length) {
      const names = inboxes.value
        .filter(inbox => failedInboxIds.includes(inbox.id))
        .map(inbox => inbox.name)
        .join(', ');
      useAlert(t('AGENT_MGMT.ADD.API.INBOX_ERROR', { inboxes: names }));
    } else {
      useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    }
    emit('close');
  } catch (error) {
    const {
      response: {
        data: {
          error: errorResponse = '',
          attributes: attributes = [],
          message: attrError = '',
        } = {},
      } = {},
    } = error;

    let errorMessage = '';
    if (error?.response?.status === 422 && !attributes.includes('base')) {
      errorMessage = t('AGENT_MGMT.ADD.API.EXIST_MESSAGE');
    } else {
      errorMessage = t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');
    }
    useAlert(errorResponse || attrError || errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="addAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentEmail.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
          <input
            v-model="agentEmail"
            type="email"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
            @input="v$.agentEmail.$touch"
          />
        </label>
      </div>

      <div class="w-full mb-4">
        <span class="block mb-1 text-sm font-medium text-n-slate-12">
          {{ $t('AGENT_MGMT.ADD.FORM.INBOXES.LABEL') }}
        </span>
        <p class="mb-2 text-xs text-n-slate-11">
          {{ $t('AGENT_MGMT.ADD.FORM.INBOXES.HELP') }}
        </p>
        <p v-if="!inboxGroups.length" class="text-sm text-n-slate-11">
          {{ $t('AGENT_MGMT.ADD.FORM.INBOXES.EMPTY') }}
        </p>
        <div
          v-else
          class="flex flex-col gap-3 p-3 overflow-y-auto border rounded-lg max-h-60 border-n-weak"
        >
          <div v-for="group in inboxGroups" :key="group.key">
            <label class="flex items-center gap-2 mb-1 text-sm font-medium">
              <Checkbox
                :model-value="selectedInGroup(group) === group.inboxes.length"
                :indeterminate="
                  selectedInGroup(group) > 0 &&
                  selectedInGroup(group) < group.inboxes.length
                "
                @update:model-value="checked => toggleGroup(group, checked)"
              />
              {{ group.label }}
            </label>
            <label
              v-for="inbox in group.inboxes"
              :key="inbox.id"
              class="flex items-center gap-2 py-0.5 ps-6 text-sm text-n-slate-12"
            >
              <Checkbox
                :model-value="isSelected(inbox.id)"
                @update:model-value="checked => toggleInbox(inbox.id, checked)"
              />
              {{ inbox.name }}
            </label>
          </div>
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
