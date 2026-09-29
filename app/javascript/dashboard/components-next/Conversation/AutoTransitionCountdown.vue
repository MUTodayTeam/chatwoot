<script setup>
import { computed, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  findLiveChatRule,
  findProjectForInbox,
  formatCountdown,
  getAutoTransition,
} from 'dashboard/helper/conversationListRow';

// Solved conversations close and pending ones solve by themselves; this counts down to it.
const props = defineProps({
  chat: { type: Object, required: true },
});

const TICK_INTERVAL = 1000;

const { t } = useI18n();

const projects = useMapGetter('projects/getProjects');
const rules = useMapGetter('liveChatRules/getLiveChatRules');
const inboxGetter = useMapGetter('inboxes/getInbox');

const transition = computed(() => {
  const project = findProjectForInbox(projects.value, props.chat.inbox_id);
  const rule = findLiveChatRule(rules.value, project?.id);
  return getAutoTransition(
    props.chat,
    rule,
    inboxGetter.value(props.chat.inbox_id)
  );
});

const nowInSeconds = () => Math.floor(Date.now() / 1000);
const now = ref(nowInSeconds());
let timer = null;

const stop = () => {
  clearInterval(timer);
  timer = null;
};

// Only rows that have a transition keep a timer running.
watch(
  transition,
  value => {
    if (value && !timer) {
      now.value = nowInSeconds();
      timer = setInterval(() => {
        now.value = nowInSeconds();
      }, TICK_INTERVAL);
    } else if (!value) {
      stop();
    }
  },
  { immediate: true }
);
onUnmounted(stop);

const text = computed(() => {
  const { target, dueAt } = transition.value;
  const remaining = dueAt - now.value;
  return t(`CHAT_LIST.CARD.AUTO_TRANSITION.${target}`, {
    time: formatCountdown(remaining),
  });
});
</script>

<template>
  <span
    v-if="transition"
    class="text-xxs tabular-nums text-n-slate-11 whitespace-nowrap"
  >
    {{ text }}
  </span>
</template>
