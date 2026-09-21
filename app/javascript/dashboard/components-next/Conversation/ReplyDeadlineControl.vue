<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import ReplyCountdown from 'dashboard/components-next/Conversation/ReplyCountdown.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

// Matches the column default on live_chat_rules, used until the rules load.
const DEFAULT_EXTENSION_MINUTES = 60;

const { t } = useI18n();
const store = useStore();

const isExtending = ref(false);

const rules = useMapGetter('liveChatRules/getLiveChatRules');
const projects = useMapGetter('projects/getProjects');

const replyDueAt = computed(() => props.chat.reply_due_at ?? 0);
const isWaiting = computed(() => replyDueAt.value > 0);

// The project is read from the projects list rather than from the inbox payload:
// inboxes are served from an IndexedDB cache that only refreshes when an inbox
// changes, so a freshly added field can be missing there for a while.
const projectId = computed(
  () =>
    projects.value.find(project =>
      project.inboxIds?.includes(props.chat.inbox_id)
    )?.id ?? null
);

// How much the button grants is a per-project setting, so it is resolved here
// rather than sent with every conversation in the list payload.
const extensionMinutes = computed(() => {
  const rule =
    rules.value.find(item => item.projectId === projectId.value) ||
    rules.value.find(item => !item.projectId);
  return rule?.extensionMinutes ?? DEFAULT_EXTENSION_MINUTES;
});

onMounted(() => {
  if (!rules.value.length) store.dispatch('liveChatRules/get');
  if (!projects.value.length) store.dispatch('projects/get');
});

const onExtend = async () => {
  isExtending.value = true;
  try {
    await store.dispatch('extendReplyDeadline', {
      conversationId: props.chat.id,
    });
    useAlert(
      t('CONVERSATION.REPLY_COUNTDOWN.EXTENDED', { n: extensionMinutes.value })
    );
  } catch (error) {
    useAlert(t('CONVERSATION.REPLY_COUNTDOWN.EXTEND_ERROR'));
  } finally {
    isExtending.value = false;
  }
};
</script>

<template>
  <div v-if="isWaiting" class="flex items-center gap-1">
    <ReplyCountdown :reply-due-at="replyDueAt" show-label />
    <Button
      v-tooltip.top="
        $t('CONVERSATION.REPLY_COUNTDOWN.EXTEND_TOOLTIP', {
          n: extensionMinutes,
        })
      "
      :label="`+${extensionMinutes}`"
      slate
      faded
      sm
      :is-loading="isExtending"
      :disabled="isExtending"
      @click="onExtend"
    />
  </div>
</template>
