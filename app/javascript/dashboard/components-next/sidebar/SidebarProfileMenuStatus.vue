<script setup>
import { computed } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { getAgentStatusMeta } from 'dashboard/constants/agentStatus';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import { provideDropdownTeleport } from 'next/dropdown-menu/base/provider';
import Icon from 'next/icon/Icon.vue';
import Button from 'next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import AgentStatusList from './AgentStatusList.vue';

// Stock Chatwoot's availability row, with the agent's statuses (CDP spec §1) in its dropdown
const { t } = useI18n();

// The profile menu sits at the foot of the sidebar, so the list floats where it fits on screen
provideDropdownTeleport();
const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserAutoOffline = useMapGetter('getCurrentUserAutoOffline');
const currentStatus = useMapGetter('agentStatus/getAgentStatus');

const activeStatus = computed(() => getAgentStatusMeta(currentStatus.value));

const autoOfflineToggle = computed({
  get: () => currentUserAutoOffline.value,
  set: autoOffline => {
    store.dispatch('updateAutoOffline', {
      accountId: currentAccountId.value,
      autoOffline,
    });
  },
});
</script>

<template>
  <DropdownSection class="[&>ul]:overflow-visible">
    <div class="grid gap-0">
      <DropdownItem preserve-open class="gap-1">
        <div class="flex-grow min-w-0">
          {{ t('SIDEBAR_ITEMS.AGENT_STATUS.TITLE') }}
          <Icon
            v-tooltip.top="t('SIDEBAR_ITEMS.AGENT_STATUS.FOOTNOTE')"
            icon="i-lucide-info"
            class="inline-block align-middle ms-1 size-4 text-n-slate-10"
          />
        </div>
        <DropdownContainer class="shrink-0">
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
                <span class="truncate max-w-[8rem]">
                  {{ t(activeStatus.labelKey) }}
                </span>
              </span>
            </Button>
          </template>
          <DropdownBody strong class="w-64">
            <AgentStatusList />
          </DropdownBody>
        </DropdownContainer>
      </DropdownItem>
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
    </div>
  </DropdownSection>
</template>
