<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  AI_ASSIGNEE_TYPES,
  getLifecycleStatus,
} from 'dashboard/helper/conversationLifecycle';
import {
  findProjectForInbox,
  getStatusChipClass,
} from 'dashboard/helper/conversationListRow';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// The list row's tags: the project, the lifecycle status and who has the conversation.
const props = defineProps({
  chat: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
});

const { t } = useI18n();

const projects = useMapGetter('projects/getProjects');

const project = computed(() =>
  findProjectForInbox(projects.value, props.chat.inbox_id)
);

const lifecycleStatus = computed(() => getLifecycleStatus(props.chat));

const isAIAssignee = computed(() =>
  AI_ASSIGNEE_TYPES.includes(props.chat.meta?.assignee_type)
);
</script>

<template>
  <div class="flex items-center gap-1.5 min-w-0 text-xxs">
    <span
      v-if="project"
      class="px-1.5 border border-n-weak rounded-sm text-n-slate-11 truncate max-w-24 flex-shrink-0"
    >
      {{ project.name }}
    </span>
    <span
      class="px-1.5 rounded-sm font-semibold uppercase tracking-wide flex-shrink-0"
      :class="getStatusChipClass(lifecycleStatus)"
    >
      {{ t(`CONVERSATION.STATUS_DROPDOWN.STATUSES.${lifecycleStatus}`) }}
    </span>
    <span
      v-if="assignee.name"
      class="inline-flex items-center gap-px min-w-0 text-n-slate-11"
    >
      <Icon
        :icon="isAIAssignee ? 'i-lucide-bot' : 'i-lucide-user-round'"
        class="size-3 flex-shrink-0"
      />
      <span class="truncate">{{ assignee.name }}</span>
    </span>
    <span v-else class="truncate text-n-slate-11">
      {{ t('CHAT_LIST.CARD.UNASSIGNED') }}
    </span>
  </div>
</template>
