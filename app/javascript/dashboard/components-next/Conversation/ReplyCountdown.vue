<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useReplyCountdown } from 'dashboard/composables/useReplyCountdown';

const props = defineProps({
  replyDueAt: {
    type: Number,
    default: 0,
  },
});

const { t } = useI18n();

const replyDueAt = computed(() => props.replyDueAt);
const { isActive, isOverdue, isNearlyDue, formattedTime } =
  useReplyCountdown(replyDueAt);

const toneClasses = computed(() => {
  if (isOverdue.value) return 'bg-n-ruby-9 text-white';
  if (isNearlyDue.value) return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-slate-3 text-n-slate-11';
});

const label = computed(() => {
  if (isOverdue.value) return t('CONVERSATION.REPLY_COUNTDOWN.OVERDUE');
  if (isNearlyDue.value) return t('CONVERSATION.REPLY_COUNTDOWN.NEARLY_DUE');
  return t('CONVERSATION.REPLY_COUNTDOWN.WITHIN');
});

defineExpose({ isActive });
</script>

<template>
  <div
    v-if="isActive"
    class="flex items-center gap-1 px-1.5 py-0.5 min-w-fit"
    :class="toneClasses"
    :title="label"
  >
    <span class="i-lucide-timer size-3" />
    <span class="text-xs font-semibold tabular-nums">{{ formattedTime }}</span>
  </div>
</template>
