<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onMounted, ref } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@chatwoot/pico-search';
import {
  useStoreGetters,
  useStore,
  useMapGetter,
} from 'dashboard/composables/store';

import AddAgent from './AddAgent.vue';
import EditAgent from './EditAgent.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import {
  ALL_OPTIONS_VALUE,
  filterAgents,
  mapTeamIdsByAgent,
  projectsForTeams,
} from './helpers/agentAccessHelper';
import {
  DEFAULT_PRESENCE,
  PRESENCE_DOT_CLASSES,
  formatAgentLoad,
  isAgentAtLimit,
} from 'dashboard/helper/agentAssignment';
import {
  getAgentStatusMeta,
  liveAgentStatus,
} from 'dashboard/constants/agentStatus';

const ROLES = ['administrator', 'agent'];

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const loading = ref({});
const showAddPopup = ref(false);
const showDeletePopup = ref(false);
const showEditPopup = ref(false);
const agentAPI = ref({ message: '' });
const currentAgent = ref({});
const searchQuery = ref('');
const roleFilter = ref(ALL_OPTIONS_VALUE);
const projectFilter = ref(ALL_OPTIONS_VALUE);

const deleteConfirmText = computed(
  () => `${t('AGENT_MGMT.DELETE.CONFIRM.YES')} ${currentAgent.value.name}`
);
const deleteRejectText = computed(() => {
  return `${t('AGENT_MGMT.DELETE.CONFIRM.NO')} ${currentAgent.value.name}`;
});
const deleteMessage = computed(() => {
  return ` ${currentAgent.value.name}?`;
});

const agentList = computed(() => getters['agents/getAgents'].value);

const teams = useMapGetter('teams/getTeams');
const teamMembersOf = useMapGetter('teamMembers/getTeamMembers');
const projects = useMapGetter('projects/getProjects');

const teamIdsByAgent = computed(() =>
  mapTeamIdsByAgent(teams.value, teamMembersOf.value)
);
const presenceOf = agent => agent.availability_status || DEFAULT_PRESENCE;
const teamIdsOf = agent => teamIdsByAgent.value[agent.id] ?? [];
const projectsOf = agent => projectsForTeams(projects.value, teamIdsOf(agent));

const teamNamesOf = agent =>
  teams.value
    .filter(team => teamIdsOf(agent).includes(team.id))
    .map(team => team.name)
    .join(', ');
const projectNamesOf = agent =>
  projectsOf(agent)
    .map(project => project.name)
    .join(', ');

const roleOptions = computed(() => [
  { value: ALL_OPTIONS_VALUE, label: t('AGENT_MGMT.FILTER.ALL_ROLES') },
  ...ROLES.map(role => ({
    value: role,
    label: t(`AGENT_MGMT.AGENT_TYPES.${role.toUpperCase()}`),
  })),
]);
const projectOptions = computed(() => [
  { value: ALL_OPTIONS_VALUE, label: t('AGENT_MGMT.FILTER.ALL_PROJECTS') },
  ...projects.value.map(project => ({
    value: project.id,
    label: project.name,
  })),
]);

const isFiltering = computed(
  () =>
    Boolean(searchQuery.value.trim()) ||
    roleFilter.value !== ALL_OPTIONS_VALUE ||
    projectFilter.value !== ALL_OPTIONS_VALUE
);

const filteredAgentList = computed(() => {
  const query = searchQuery.value.trim();
  const searched = query
    ? picoSearch(agentList.value, query, ['name', 'email'])
    : agentList.value;
  return filterAgents(
    searched,
    { role: roleFilter.value, projectId: projectFilter.value },
    agent => projectsOf(agent).map(project => project.id)
  );
});

const tableHeaders = computed(() => [
  t('AGENT_MGMT.LIST.NAME'),
  t('AGENT_MGMT.LIST.EMAIL'),
  t('AGENT_MGMT.LIST.ROLE'),
  t('AGENT_MGMT.LIST.TEAMS'),
  t('AGENT_MGMT.LIST.PROJECTS'),
  t('AGENT_MGMT.LIST.PRESENCE'),
  t('AGENT_MGMT.LIST.CHAT_LIMIT'),
  t('AGENT_MGMT.LIST.STATUS'),
  t('AGENT_MGMT.LIST.ACTIONS'),
]);

const uiFlags = computed(() => getters['agents/getUIFlags'].value);
const currentUserId = computed(() => getters.getCurrentUserID.value);
const customRoles = useMapGetter('customRole/getCustomRoles');

// Team membership is loaded per team, so the list can show each agent's teams and the
// projects those teams are entitled to.
const fetchTeamMembers = async () => {
  await store.dispatch('teams/get');
  await Promise.all(
    teams.value.map(team =>
      store.dispatch('teamMembers/get', { teamId: team.id })
    )
  );
};

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('customRole/getCustomRole');
  store.dispatch('projects/get');
  fetchTeamMembers();
});

const findCustomRole = agent =>
  customRoles.value.find(role => role.id === agent.custom_role_id);

const getAgentRoleName = agent => {
  if (!agent.custom_role_id) {
    return t(`AGENT_MGMT.AGENT_TYPES.${agent.role.toUpperCase()}`);
  }
  const customRole = findCustomRole(agent);
  return customRole ? customRole.name : '';
};

const getAgentRolePermissions = agent => {
  if (!agent.custom_role_id) {
    return [];
  }
  const customRole = findCustomRole(agent);
  return customRole?.permissions || [];
};

const verifiedAdministrators = computed(() => {
  return agentList.value.filter(
    agent => agent.role === 'administrator' && agent.confirmed
  );
});

const showEditAction = agent => {
  return currentUserId.value !== agent.id;
};

const showDeleteAction = agent => {
  if (currentUserId.value === agent.id) {
    return false;
  }

  if (!agent.confirmed) {
    return true;
  }

  if (agent.role === 'administrator') {
    return verifiedAdministrators.value.length !== 1;
  }
  return true;
};

const showAlertMessage = message => {
  loading.value[currentAgent.value.id] = false;
  currentAgent.value = {};
  agentAPI.value.message = message;
  useAlert(message);
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = agent => {
  showEditPopup.value = true;
  currentAgent.value = agent;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = agent => {
  showDeletePopup.value = true;
  currentAgent.value = agent;
};
const closeDeletePopup = () => {
  showDeletePopup.value = false;
};

const deleteAgent = async id => {
  try {
    await store.dispatch('agents/delete', id);
    showAlertMessage(t('AGENT_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    showAlertMessage(t('AGENT_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const confirmDeletion = () => {
  loading.value[currentAgent.value.id] = true;
  closeDeletePopup();
  deleteAgent(currentAgent.value.id);
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('AGENT_MGMT.LOADING')"
    :no-records-found="!agentList.length"
    :no-records-message="$t('AGENT_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('AGENT_MGMT.HEADER')"
        :description="$t('AGENT_MGMT.DESCRIPTION')"
        :link-text="$t('AGENT_MGMT.LEARN_MORE')"
        :search-placeholder="$t('AGENT_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="agents"
      >
        <template v-if="agentList?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('AGENT_MGMT.COUNT', { n: agentList.length }) }}
          </span>
        </template>
        <template #actions>
          <Select
            v-model="projectFilter"
            :options="projectOptions"
            :aria-label="$t('AGENT_MGMT.FILTER.PROJECT')"
          />
          <Select
            v-model="roleFilter"
            :options="roleOptions"
            :aria-label="$t('AGENT_MGMT.FILTER.ROLE')"
          />
          <Button
            :label="$t('AGENT_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <span
        v-if="!filteredAgentList.length && isFiltering"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{ $t('AGENT_MGMT.NO_RESULTS') }}
      </span>
      <div v-else class="overflow-x-auto">
        <BaseTable :headers="tableHeaders" :items="filteredAgentList">
          <template #row="{ items }">
            <BaseTableRow
              v-for="agent in items"
              :key="agent.email"
              :item="agent"
            >
              <BaseTableCell>
                <div class="flex items-center gap-3">
                  <Avatar
                    :src="agent.thumbnail"
                    :name="agent.name"
                    :status="agent.availability_status"
                    :size="32"
                    hide-offline-status
                  />
                  <span class="text-body-main text-n-slate-12 capitalize">
                    {{ agent.name }}
                  </span>
                </div>
              </BaseTableCell>
              <BaseTableCell>{{ agent.email }}</BaseTableCell>
              <BaseTableCell>
                <span
                  class="block w-fit relative"
                  :class="{
                    'hover:text-n-slate-12 group cursor-pointer':
                      agent.custom_role_id,
                  }"
                >
                  {{ getAgentRoleName(agent) }}

                  <div
                    class="absolute start-0 z-10 hidden w-[300px] bg-n-alpha-3 backdrop-blur-[100px] rounded-xl outline outline-1 outline-n-container shadow-lg top-8"
                    :class="{ 'group-hover:block': agent.custom_role_id }"
                  >
                    <div class="flex flex-col gap-1 p-4">
                      <span class="text-heading-3 text-n-slate-12">
                        {{ $t('AGENT_MGMT.LIST.AVAILABLE_CUSTOM_ROLE') }}
                      </span>
                      <ul class="ps-4 mb-0 list-disc">
                        <li
                          v-for="permission in getAgentRolePermissions(agent)"
                          :key="permission"
                          class="text-body-main text-n-slate-11"
                        >
                          {{
                            $t(
                              `CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`
                            )
                          }}
                        </li>
                      </ul>
                    </div>
                  </div>
                </span>
              </BaseTableCell>
              <BaseTableCell>{{ teamNamesOf(agent) }}</BaseTableCell>
              <BaseTableCell>{{ projectNamesOf(agent) }}</BaseTableCell>
              <BaseTableCell>
                <span class="inline-flex items-center gap-1.5">
                  <span
                    class="rounded-full size-2 flex-shrink-0"
                    :class="PRESENCE_DOT_CLASSES[presenceOf(agent)]"
                  />
                  {{ $t(getAgentStatusMeta(liveAgentStatus(agent)).labelKey) }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span
                  v-tooltip.top="$t('AGENT_MGMT.LIST.CHAT_LIMIT_TOOLTIP')"
                  class="tabular-nums"
                  :class="{
                    'text-n-ruby-11': isAgentAtLimit(agent.conversation_load),
                  }"
                >
                  {{ formatAgentLoad(agent.conversation_load) }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                {{
                  agent.confirmed
                    ? $t('AGENT_MGMT.LIST.VERIFIED')
                    : $t('AGENT_MGMT.LIST.VERIFICATION_PENDING')
                }}
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex justify-end gap-3">
                  <Button
                    v-if="showEditAction(agent)"
                    v-tooltip.top="$t('AGENT_MGMT.EDIT.BUTTON_TEXT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(agent)"
                  />
                  <Button
                    v-if="showDeleteAction(agent)"
                    v-tooltip.top="$t('AGENT_MGMT.DELETE.BUTTON_TEXT')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[agent.id]"
                    @click="openDeletePopup(agent)"
                  />
                </div>
              </BaseTableCell>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>
    </template>

    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddAgent @close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditAgent
        v-if="showEditPopup"
        :id="currentAgent.id"
        :name="currentAgent.name"
        :provider="currentAgent.provider"
        :type="currentAgent.role"
        :email="currentAgent.email"
        :availability="currentAgent.availability_status"
        :custom-role-id="currentAgent.custom_role_id"
        @close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeletePopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('AGENT_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('AGENT_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </SettingsLayout>
</template>
