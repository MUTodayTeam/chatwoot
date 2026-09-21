import { computed, onUnmounted, ref, unref } from 'vue';

const TICK_INTERVAL = 1000;
// Below this many seconds left the chip warns that the deadline is close.
const NEARLY_DUE_SECONDS = 300;

const pad = value => String(value).padStart(2, '0');

/**
 * Live countdown to the moment a customer has been waiting too long for a reply.
 *
 * `replyDueAt` is a unix timestamp in seconds, or 0/null when nobody is waiting
 * (the agent has replied, or the conversation is resolved) — in which case the
 * countdown reports itself inactive and no timer runs.
 */
export const useReplyCountdown = replyDueAt => {
  const now = ref(Math.floor(Date.now() / 1000));
  let timer = null;

  const dueAt = computed(() => Number(unref(replyDueAt)) || 0);
  const isActive = computed(() => dueAt.value > 0);
  const remainingSeconds = computed(() =>
    isActive.value ? dueAt.value - now.value : 0
  );
  const isOverdue = computed(
    () => isActive.value && remainingSeconds.value < 0
  );
  const isNearlyDue = computed(
    () =>
      isActive.value &&
      remainingSeconds.value >= 0 &&
      remainingSeconds.value < NEARLY_DUE_SECONDS
  );

  // Counts up once overdue, so the chip shows how far past the deadline it is.
  const formattedTime = computed(() => {
    const total = Math.abs(remainingSeconds.value);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const seconds = total % 60;
    const clock = hours
      ? `${hours}:${pad(minutes)}:${pad(seconds)}`
      : `${pad(minutes)}:${pad(seconds)}`;

    return isOverdue.value ? `-${clock}` : clock;
  });

  const stop = () => {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  };

  const start = () => {
    stop();
    timer = setInterval(() => {
      now.value = Math.floor(Date.now() / 1000);
    }, TICK_INTERVAL);
  };

  start();
  onUnmounted(stop);

  return {
    isActive,
    isOverdue,
    isNearlyDue,
    remainingSeconds,
    formattedTime,
  };
};
