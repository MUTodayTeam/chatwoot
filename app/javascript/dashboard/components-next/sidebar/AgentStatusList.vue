<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';
import { AGENT_STATUSES } from 'dashboard/constants/agentStatus';

import { DropdownSeparator, DropdownItem } from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';

// The agent's statuses (CDP spec §1), each with today's time in it, so one pick changes the
// status and closes the menu. Only Ready receives chats automatically.
const { t } = useI18n();
const store = useStore();
const currentStatus = useMapGetter('agentStatus/getAgentStatus');
const today = useMapGetter('agentStatus/getToday');
const fetchedAt = useMapGetter('agentStatus/getFetchedAt');

const { isImpersonating } = useImpersonation();

// Re-read on every open, and let the open status keep counting while the menu is shown
const now = ref(Date.now());
let timer;
onMounted(() => {
  store.dispatch('agentStatus/fetch');
  timer = setInterval(() => {
    now.value = Date.now();
  }, 1000);
});
onUnmounted(() => clearInterval(timer));

const secondsSinceFetch = computed(() =>
  Math.max(0, Math.floor((now.value - fetchedAt.value) / 1000))
);

const formatDuration = totalSeconds => {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return `${hours}:${String(minutes).padStart(2, '0')}`;
};

const secondsIn = status =>
  (today.value[status] || 0) +
  (currentStatus.value === status ? secondsSinceFetch.value : 0);

// Offline is not part of the day's online time, so it shows no duration
const statuses = computed(() =>
  AGENT_STATUSES.map(status => ({
    ...status,
    label: t(status.labelKey),
    active: currentStatus.value === status.value,
    duration:
      status.value === 'offline' ? '' : formatDuration(secondsIn(status.value)),
  }))
);

const onlineTotal = computed(() =>
  formatDuration(
    (today.value.online_total || 0) +
      (currentStatus.value === 'offline' ? 0 : secondsSinceFetch.value)
  )
);

async function changeStatus(status) {
  if (isImpersonating.value) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
    return;
  }
  try {
    await store.dispatch('agentStatus/set', { status });
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
  }
}
</script>

<template>
  <DropdownItem
    v-for="status in statuses"
    :key="status.value"
    class="cursor-pointer"
    :class="{ 'bg-n-alpha-1 font-medium': status.active }"
    :click="() => changeStatus(status.value)"
  >
    <template #icon>
      <span class="flex-shrink-0 size-2 rounded-sm" :class="status.color" />
    </template>
    <template #label>
      <span class="flex-grow min-w-0 truncate">{{ status.label }}</span>
      <span class="flex-shrink-0 tabular-nums text-n-slate-11">
        {{ status.duration }}
      </span>
      <span class="flex-shrink-0 size-4">
        <Icon
          v-if="status.active"
          icon="i-lucide-check"
          class="size-4 text-n-slate-11"
        />
      </span>
    </template>
  </DropdownItem>
  <DropdownSeparator />
  <li
    class="flex items-center gap-3 px-2 py-1 text-xs list-none text-n-slate-11"
  >
    <span class="flex-grow min-w-0 truncate">
      {{ t('SIDEBAR_ITEMS.AGENT_STATUS.ONLINE_TOTAL') }}
    </span>
    <span class="flex-shrink-0 font-medium tabular-nums text-n-slate-12">
      {{ onlineTotal }}
    </span>
    <span class="flex-shrink-0 size-4" />
  </li>
</template>
