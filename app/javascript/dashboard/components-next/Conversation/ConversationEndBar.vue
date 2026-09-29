<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useInboxProject } from 'dashboard/composables/useInboxProject';
import { CONVERSATION_STATUS } from 'shared/constants/messages';
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

// Seam for the categories PR: show the category picked at Solved here. Until a
// conversation carries one, every topic is Other, as bulk Solved records it.
const topic = computed(() => t('CONVERSATION.END_BAR.OTHER_TOPIC'));

const closesIn = computed(() => {
  const statusChangedAt = props.chat.status_changed_at;
  if (!isSolved.value || !statusChangedAt) return '';

  const rule = findLiveChatRule(rules.value, project.value?.id ?? null);
  const seconds = autoCloseRemainingSeconds({
    statusChangedAt,
    autoCloseHours: rule?.autoCloseHours ?? DEFAULT_AUTO_CLOSE_HOURS,
    now: now.value,
  });
  return formatCountdown(seconds);
});

const reopenNote = computed(() =>
  props.chat.case
    ? t('CONVERSATION.END_BAR.REOPEN_NOTE', {
        display: props.chat.case.display,
      })
    : t('CONVERSATION.END_BAR.REOPEN_NOTE_NO_CASE')
);

// Seam for the handlers PR: switch to its dedicated reopen endpoint once it lands.
const reopen = async () => {
  isReopening.value = true;
  try {
    await store.dispatch('toggleStatus', {
      conversationId: props.chat.id,
      status: CONVERSATION_STATUS.OPEN,
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
      <span class="font-medium text-n-slate-12">{{ statusLabel }}</span>
      ·
      {{ t('CONVERSATION.END_BAR.TOPIC') }}
      <span class="font-medium text-n-slate-12">{{ topic }}</span>
      <span v-if="closesIn" class="ms-1 tabular-nums">
        {{ t('CONVERSATION.END_BAR.CLOSES_IN', { time: closesIn }) }}
      </span>
    </span>
    <span class="ms-auto text-label-small">{{ reopenNote }}</span>
    <Button
      v-if="isSolved"
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
