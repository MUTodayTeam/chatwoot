<script setup>
import { computed, onMounted, watch } from 'vue';
import { useIntervalFn } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { getAgentStatusMeta } from 'dashboard/constants/agentStatus';

import { DropdownContainer, DropdownBody } from 'next/dropdown-menu/base';
import Button from 'next/button/Button.vue';
import SidebarProfileMenuStatus from './SidebarProfileMenuStatus.vue';

// "<status> · <active>/<limit> cases" (CDP spec §1). Opens the agent's own status menu.
// The limit is the current project's chat limit, the account default without a project.
const props = defineProps({
  projectId: { type: Number, default: null },
});

const REFRESH_INTERVAL_MS = 60 * 1000;

const { t } = useI18n();
const store = useStore();
const currentStatus = useMapGetter('agentStatus/getAgentStatus');
const load = useMapGetter('agentStatus/getLoad');
const fetchedAt = useMapGetter('agentStatus/getFetchedAt');

const fetchStatus = () => store.dispatch('agentStatus/fetch', props.projectId);

onMounted(fetchStatus);
watch(() => props.projectId, fetchStatus);
useIntervalFn(fetchStatus, REFRESH_INTERVAL_MS);

const activeStatus = computed(() => getAgentStatusMeta(currentStatus.value));
const statusLabel = computed(() => t(activeStatus.value.labelKey));

const pillText = computed(() =>
  load.value.limit
    ? t('SIDEBAR_ITEMS.AGENT_STATUS.PILL', {
        status: statusLabel.value,
        active: load.value.active,
        limit: load.value.limit,
      })
    : statusLabel.value
);
</script>

<template>
  <!-- Hidden until the first fetch lands, so a Busy sign-in never flashes as Ready -->
  <DropdownContainer class="flex-shrink-0" :class="{ hidden: !fetchedAt }">
    <template #trigger="{ toggle }">
      <Button
        size="sm"
        color="slate"
        variant="faded"
        icon="i-lucide-chevron-down"
        trailing-icon
        @click="toggle"
      >
        <span class="flex items-center gap-2 min-w-0 text-sm">
          <span
            class="flex-shrink-0 size-2 rounded-sm"
            :class="activeStatus.color"
          />
          <span class="truncate max-w-[10rem]">{{ pillText }}</span>
        </span>
      </Button>
    </template>
    <DropdownBody class="z-50 mt-1 w-72 ltr:left-0 rtl:right-0">
      <SidebarProfileMenuStatus />
    </DropdownBody>
  </DropdownContainer>
</template>
