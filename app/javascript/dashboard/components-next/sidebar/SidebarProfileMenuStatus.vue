<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';
import {
  AGENT_STATUSES,
  getAgentStatusMeta,
} from 'dashboard/constants/agentStatus';

import {
  DropdownSection,
  DropdownSeparator,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

// The agent's own status menu (CDP spec §1): pick a status, see today's time in each. Only
// Ready receives chats automatically.
const { t } = useI18n();
const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserAutoOffline = useMapGetter('getCurrentUserAutoOffline');
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

const statuses = computed(() =>
  AGENT_STATUSES.map(status => ({
    ...status,
    label: t(status.labelKey),
    active: currentStatus.value === status.value,
  }))
);

const activeStatus = computed(() => getAgentStatusMeta(currentStatus.value));

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

const summaryRows = computed(() =>
  statuses.value
    .filter(status => status.value !== 'offline')
    .map(status => ({
      ...status,
      duration: formatDuration(secondsIn(status.value)),
    }))
);

const onlineTotal = computed(() =>
  formatDuration(
    (today.value.online_total || 0) +
      (currentStatus.value === 'offline' ? 0 : secondsSinceFetch.value)
  )
);

const autoOfflineToggle = computed({
  get: () => currentUserAutoOffline.value,
  set: autoOffline => {
    store.dispatch('updateAutoOffline', {
      accountId: currentAccountId.value,
      autoOffline,
    });
  },
});

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
  <div class="grid gap-2">
    <div class="flex items-center justify-between gap-2 px-2 pt-1">
      <span class="text-xs font-medium text-n-slate-10">
        {{ t('SIDEBAR_ITEMS.AGENT_STATUS.TITLE') }}
      </span>
      <span
        class="flex items-center gap-2 min-w-0 text-sm font-medium text-n-slate-12"
      >
        <span
          class="flex-shrink-0 size-2 rounded-sm"
          :class="activeStatus.color"
        />
        <span class="truncate">{{ t(activeStatus.labelKey) }}</span>
      </span>
    </div>
    <DropdownSection>
      <DropdownItem
        v-for="status in statuses"
        :key="status.value"
        preserve-open
        class="cursor-pointer"
        :click="() => changeStatus(status.value)"
      >
        <template #icon>
          <span class="flex-shrink-0 size-2 rounded-sm" :class="status.color" />
        </template>
        <template #label>
          <span class="flex-grow min-w-0 truncate">{{ status.label }}</span>
          <Icon
            v-if="status.active"
            icon="i-lucide-check"
            class="flex-shrink-0 size-4 text-n-slate-11"
          />
        </template>
      </DropdownItem>
    </DropdownSection>
    <DropdownSeparator />
    <DropdownSection :title="t('SIDEBAR_ITEMS.AGENT_STATUS.SUMMARY_TITLE')">
      <DropdownItem
        v-for="row in summaryRows"
        :key="row.value"
        class="gap-3 !py-1"
      >
        <span class="flex-shrink-0 size-2 rounded-sm" :class="row.color" />
        <span class="flex-grow min-w-0 truncate">{{ row.label }}</span>
        <span class="tabular-nums text-n-slate-11">{{ row.duration }}</span>
      </DropdownItem>
      <DropdownItem class="gap-3 !py-1 font-medium">
        <span class="flex-grow min-w-0 truncate">
          {{ t('SIDEBAR_ITEMS.AGENT_STATUS.ONLINE_TOTAL') }}
        </span>
        <span class="tabular-nums text-n-slate-11">{{ onlineTotal }}</span>
      </DropdownItem>
    </DropdownSection>
    <p class="px-2 text-xs text-n-slate-10">
      {{ t('SIDEBAR_ITEMS.AGENT_STATUS.FOOTNOTE') }}
    </p>
    <DropdownSeparator />
    <DropdownSection>
      <DropdownItem>
        <div class="flex-grow min-w-0">
          {{ t('SIDEBAR.SET_AUTO_OFFLINE.TEXT') }}
          <Icon
            v-tooltip.top="t('SIDEBAR.SET_AUTO_OFFLINE.INFO_SHORT')"
            icon="i-lucide-info"
            class="inline-block align-middle ms-1 size-4 text-n-slate-10"
          />
        </div>
        <ToggleSwitch v-model="autoOfflineToggle" />
      </DropdownItem>
    </DropdownSection>
  </div>
</template>
