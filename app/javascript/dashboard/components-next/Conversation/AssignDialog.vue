<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { mapTeamIdsByAgent } from 'dashboard/routes/dashboard/settings/agents/helpers/agentAccessHelper';
import { findProjectForInbox } from 'dashboard/helper/conversationListRow';
import {
  buildAssignRows,
  formatAgentLoad,
  isAgentAtLimit,
} from 'dashboard/helper/agentAssignment';
import {
  getAgentStatusMeta,
  liveAgentStatus,
} from 'dashboard/constants/agentStatus';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// Assign (spec 7.1): the agents entitled to the conversation's project, with their team,
// load and presence; picking one assigns straight away.
const props = defineProps({
  conversationId: {
    type: Number,
    required: true,
  },
  inboxId: {
    type: Number,
    required: true,
  },
});

const ASSIGNEE_TYPE = 'User';

const { t } = useI18n();
const store = useStore();
const assignableAgentsOf = useMapGetter(
  'inboxAssignableAgents/getAssignableAgents'
);
const liveAgents = useMapGetter('agents/getAgents');
const currentUser = useMapGetter('getCurrentUser');
const accountId = useMapGetter('getCurrentAccountId');
const projects = useMapGetter('projects/getProjects');
const teams = useMapGetter('teams/getTeams');
const teamMembersOf = useMapGetter('teamMembers/getTeamMembers');

const dialogRef = ref(null);
const query = ref('');
const isFetching = ref(false);
const assigningTo = ref(null);

const projectTeams = computed(() => {
  const project = findProjectForInbox(projects.value, props.inboxId);
  const teamIds = project?.teamIds ?? [];
  return teams.value.filter(team => teamIds.includes(team.id));
});

const rows = computed(() =>
  buildAssignRows({
    agents: assignableAgentsOf.value(props.inboxId),
    liveAgents: liveAgents.value,
    currentUser: currentUser.value,
    accountId: accountId.value,
    teams: projectTeams.value,
    teamIdsByAgent: mapTeamIdsByAgent(projectTeams.value, teamMembersOf.value),
    query: query.value,
  })
);

// The load changes with every assignment, so the list is fetched each time it opens.
const fetchAgents = async () => {
  isFetching.value = true;
  try {
    await Promise.all([
      store.dispatch('inboxAssignableAgents/fetch', [props.inboxId]),
      ...projectTeams.value.map(team =>
        store.dispatch('teamMembers/get', { teamId: team.id })
      ),
    ]);
  } catch (error) {
    useAlert(t('CONVERSATION.ASSIGN_DIALOG.FETCH_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

const open = () => {
  query.value = '';
  fetchAgents();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

defineExpose({ open, close });

const assignTo = async agent => {
  if (assigningTo.value) return;

  assigningTo.value = agent.id;
  try {
    await store.dispatch('assignAgent', {
      conversationId: props.conversationId,
      agentId: agent.id,
      assigneeType: ASSIGNEE_TYPE,
    });
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
    close();
  } finally {
    assigningTo.value = null;
  }
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CONVERSATION.ASSIGN_DIALOG.TITLE')"
    :description="t('CONVERSATION.ASSIGN_DIALOG.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('CONVERSATION.ASSIGN_DIALOG.CANCEL')"
  >
    <div class="flex flex-col gap-3 min-w-0">
      <Input
        v-model="query"
        type="search"
        :placeholder="t('CONVERSATION.ASSIGN_DIALOG.SEARCH_PLACEHOLDER')"
        autofocus
      />

      <div class="flex flex-col overflow-y-auto max-h-[50vh] min-h-24">
        <!-- The cached rows hold the previous load, so they stay hidden until the refetch lands -->
        <div v-if="isFetching" class="flex justify-center py-6">
          <Spinner />
        </div>
        <p
          v-else-if="!rows.length"
          class="py-6 mb-0 text-center text-body-main text-n-slate-11"
        >
          {{
            query.trim()
              ? t('CONVERSATION.ASSIGN_DIALOG.NO_RESULTS')
              : t('CONVERSATION.ASSIGN_DIALOG.NO_AGENTS')
          }}
        </p>
        <template v-else>
          <button
            v-for="agent in rows"
            :key="agent.id"
            type="button"
            class="flex items-center w-full gap-3 px-1 py-2.5 border-b border-n-weak text-start hover:bg-n-alpha-1 disabled:opacity-60"
            :disabled="Boolean(assigningTo)"
            @click="assignTo(agent)"
          >
            <Avatar
              :name="agent.name"
              :src="agent.thumbnail"
              :size="28"
              :status="agent.availability_status"
            />
            <span class="flex flex-col flex-1 min-w-0">
              <span class="truncate text-body-main text-n-slate-12">
                {{ agent.available_name || agent.name }}
              </span>
              <span
                v-if="agent.teamNames.length"
                class="truncate text-label-small text-n-slate-11"
              >
                {{ agent.teamNames.join(', ') }}
              </span>
            </span>
            <span class="text-label-small text-n-slate-11 flex-shrink-0">
              {{ t(getAgentStatusMeta(liveAgentStatus(agent)).labelKey) }}
            </span>
            <Spinner v-if="assigningTo === agent.id" class="size-4" />
            <span
              v-else-if="agent.conversation_load"
              v-tooltip.top="t('CONVERSATION.ASSIGN_DIALOG.LOAD_TOOLTIP')"
              class="text-label-small tabular-nums flex-shrink-0 min-w-10 text-end"
              :class="
                isAgentAtLimit(agent.conversation_load)
                  ? 'text-n-ruby-11'
                  : 'text-n-slate-12'
              "
            >
              {{ formatAgentLoad(agent.conversation_load) }}
            </span>
          </button>
        </template>
      </div>
    </div>
  </Dialog>
</template>
