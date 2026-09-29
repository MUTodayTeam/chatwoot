<script setup>
import { computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  getProjectOpenCount,
  getProjectUnreadCount,
  resolveCurrentProject,
} from 'dashboard/helper/sidebarProjectStatus';

// The app header's current project and Agents online (CDP spec §1). Chatwoot has no
// app header, so they sit at the top of the sidebar, under search.
const { t } = useI18n();
const store = useStore();
const route = useRoute();

const projects = useMapGetter('projects/getProjects');
const agents = useMapGetter('agents/getAgents');
const agentStatus = useMapGetter('agents/getAgentStatus');
const chatListFilters = useMapGetter('getChatListFilters');
const appliedFilters = useMapGetter('getAppliedConversationFilters');
const conversationStats = useMapGetter('conversationStats/getStats');
const inboxUnreadCountOf = useMapGetter(
  'conversationUnreadCounts/getInboxUnreadCount'
);

// The conversation screens fetch agents, other pages may not have yet
onMounted(() => {
  if (!agents.value.length) store.dispatch('agents/get');
});

const project = computed(() =>
  resolveCurrentProject(projects.value, {
    projectId: route.params.projectId,
    inboxId: route.params.inbox_id,
  })
);

const projectCount = computed(() => {
  const openCount = getProjectOpenCount({
    project: project.value,
    filters: chatListFilters.value || {},
    hasAppliedFilters: appliedFilters.value.length > 0,
    allCount: conversationStats.value.allCount,
  });
  if (openCount !== null) {
    return t('SIDEBAR.PROJECT_STATUS.OPEN', { n: openCount });
  }
  const unreadCount = getProjectUnreadCount(
    project.value,
    inboxUnreadCountOf.value
  );
  return unreadCount
    ? t('SIDEBAR.PROJECT_STATUS.UNREAD', { n: unreadCount })
    : '';
});
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-x-2 gap-y-1 px-2 min-w-0 text-label-small"
  >
    <span
      v-if="project"
      v-tooltip.bottom="t('SIDEBAR.PROJECT_STATUS.CURRENT_PROJECT')"
      class="flex items-center gap-1.5 min-w-0 max-w-full"
    >
      <!-- The project's own colour, as its sidebar entry -->
      <span
        class="flex-shrink-0 rounded-full size-2 bg-n-slate-9"
        :style="project.color ? { backgroundColor: project.color } : undefined"
      />
      <span class="truncate text-n-slate-12">{{ project.name }}</span>
      <span v-if="projectCount" class="flex-shrink-0 text-n-slate-11">
        {{ projectCount }}
      </span>
    </span>
    <span class="flex items-center flex-shrink-0 gap-1 text-n-slate-11">
      <span class="rounded-full size-2 bg-n-teal-10" />
      {{ t('SIDEBAR.PROJECT_STATUS.AGENTS_ONLINE') }}
      <span class="font-semibold text-n-slate-12 tabular-nums">
        {{ agentStatus.online }}
      </span>
    </span>
  </div>
</template>
