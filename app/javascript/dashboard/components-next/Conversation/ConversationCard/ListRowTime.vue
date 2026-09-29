<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { formatListRowTime } from 'dashboard/helper/conversationListRow';

// The row's last activity as a time today and a date before, with the exact created
// and last activity times on hover as TimeAgo showed them.
const props = defineProps({
  lastActivityTimestamp: { type: Number, default: 0 },
  createdAtTimestamp: { type: Number, default: 0 },
});

// Only the day matters, so a minute is often enough to turn today's time into a date.
const CLOCK_INTERVAL = 60 * 1000;

const { t } = useI18n();
const exactTimestamp = useExactTimestamp();
const now = ref(new Date());
const timer = setInterval(() => {
  now.value = new Date();
}, CLOCK_INTERVAL);
onUnmounted(() => clearInterval(timer));

const text = computed(() =>
  formatListRowTime(props.lastActivityTimestamp, now.value)
);

const tooltipText = computed(
  () =>
    `${t('CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST')} ${exactTimestamp(props.createdAtTimestamp)}\n` +
    `${t('CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE')} ${exactTimestamp(props.lastActivityTimestamp)}`
);
</script>

<template>
  <span
    v-tooltip.top="{
      content: tooltipText,
      popperClass: 'whitespace-pre-line',
      delay: { show: 1000, hide: 0 },
    }"
  >
    {{ text }}
  </span>
</template>
