<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { I18nT, useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useInboxProject } from 'dashboard/composables/useInboxProject';
import { CONVERSATION_STATUS } from 'shared/constants/messages';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import {
  DEFAULT_AUTO_CLOSE_HOURS,
  autoCloseRemainingSeconds,
  findLiveChatRule,
  formatCountdown,
} from 'dashboard/helper/conversationEndBar';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const TICK_INTERVAL_MS = 1000;
// These channels start a new conversation after Closed (Custom::Message#reopen_conversation), so the
// customer's next message there does not reopen this one; Email and the web widget still do.
const NEW_CONVERSATION_AFTER_CLOSED = [
  INBOX_TYPES.LINE,
  INBOX_TYPES.FB,
  INBOX_TYPES.INSTAGRAM,
  INBOX_TYPES.TIKTOK,
];

const { t } = useI18n();
const store = useStore();

const isReopening = ref(false);

const rules = useMapGetter('liveChatRules/getLiveChatRules');
const project = useInboxProject(computed(() => props.chat.inbox_id));
const nowInSeconds = () => Math.floor(Date.now() / 1000);
const now = ref(nowInSeconds());
let ticker = null;

onMounted(() => {
  if (!rules.value.length) store.dispatch('liveChatRules/get');
  ticker = setInterval(() => {
    now.value = nowInSeconds();
  }, TICK_INTERVAL_MS);
});

onUnmounted(() => clearInterval(ticker));

const isSolved = computed(
  () => props.chat.status === CONVERSATION_STATUS.RESOLVED
);

const statusLabel = computed(() =>
  isSolved.value
    ? t('CONVERSATION.END_BAR.SOLVED')
    : t('CONVERSATION.END_BAR.CLOSED')
);

// The category picked at Solved; a case solved without one (list menu, bulk, auto-solve) is Other
const topic = computed(
  () => props.chat.case?.topic || t('CONVERSATION.END_BAR.OTHER_TOPIC')
);

const closesIn = computed(() => {
  if (!isSolved.value) return '';

  // Conversations solved before status_changed_at existed have none; the sweep closes
  // them on updated_at instead, so the countdown does too.
  const statusChangedAt =
    props.chat.status_changed_at || Math.floor(props.chat.updated_at);

  const rule = findLiveChatRule(rules.value, project.value?.id ?? null);
  const seconds = autoCloseRemainingSeconds({
    statusChangedAt,
    autoCloseHours: rule?.autoCloseHours ?? DEFAULT_AUTO_CLOSE_HOURS,
    now: now.value,
  });
  return formatCountdown(seconds);
});

const reopenNote = computed(() => {
  if (
    !isSolved.value &&
    NEW_CONVERSATION_AFTER_CLOSED.includes(props.chat.meta?.channel)
  ) {
    return t('CONVERSATION.END_BAR.NEW_CONVERSATION_NOTE');
  }
  return props.chat.case
    ? t('CONVERSATION.END_BAR.REOPEN_NOTE', {
        display: props.chat.case.display,
      })
    : t('CONVERSATION.END_BAR.REOPEN_NOTE_NO_CASE');
});

// The reopen endpoint gives the conversation back to an agent and opens their turn (spec 7.4)
const reopen = async () => {
  isReopening.value = true;
  try {
    await store.dispatch('reopenConversation', {
      conversationId: props.chat.id,
    });
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION.CHANGE_STATUS_FAILED'));
  } finally {
    isReopening.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-3 px-5 py-3 border-t-2 border-n-weak text-body-main text-n-slate-11"
  >
    <span>
      <I18nT keypath="CONVERSATION.END_BAR.SUMMARY" tag="span">
        <template #status>
          <span class="font-medium text-n-slate-12">{{ statusLabel }}</span>
        </template>
        <template #topic>
          <span class="font-medium text-n-slate-12">{{ topic }}</span>
        </template>
      </I18nT>
      <span v-if="closesIn" class="ms-1 tabular-nums">
        {{ t('CONVERSATION.END_BAR.CLOSES_IN', { time: closesIn }) }}
      </span>
    </span>
    <span class="ms-auto text-label-small">{{ reopenNote }}</span>
    <Button
      :label="t('CONVERSATION.END_BAR.REOPEN')"
      slate
      faded
      sm
      :is-loading="isReopening"
      :disabled="isReopening"
      @click="reopen"
    />
  </div>
</template>
