<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import camelcaseKeys from 'camelcase-keys';
import endOfDay from 'date-fns/endOfDay';
import getUnixTime from 'date-fns/getUnixTime';
import startOfDay from 'date-fns/startOfDay';
import startOfMonth from 'date-fns/startOfMonth';
import subDays from 'date-fns/subDays';

import ReportsAPI from 'dashboard/api/reports';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import HeatmapDateRangeSelector from '../heatmaps/HeatmapDateRangeSelector.vue';
import MetricCard from '../overview/MetricCard.vue';
import AgentProductivityTable from './AgentProductivityTable.vue';

const store = useStore();
const { t } = useI18n();
const { run, isPending } = useAbortableRequest();

const projects = useMapGetter('projects/getProjects');

const productivity = ref(null);
const selectedProjectId = ref(null);
const selectedFrom = ref(null);
const selectedTo = ref(null);
const selectedDaysBefore = ref(null);
const isMonthFilter = ref(false);
const currentMonthOffset = ref(0);

const [showProjectMenu, toggleProjectMenu] = useToggle();

const projectMenuItems = computed(() => [
  { label: t('OVERVIEW_REPORTS.CDP_DASHBOARD.ALL_PROJECTS'), value: null },
  ...projects.value.map(project => ({
    label: project.name,
    value: project.id,
  })),
]);

const selectedProjectLabel = computed(
  () =>
    projectMenuItems.value.find(item => item.value === selectedProjectId.value)
      ?.label
);

const isLoading = computed(() => isPending.value && !productivity.value);

const scoreNote = computed(() => {
  if (!productivity.value) return '';

  const { assisted, transferPenalty } = productivity.value.weights;
  return t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.SCORE_NOTE', {
    assisted,
    penalty: transferPenalty,
  });
});

// Keeps relative presets (last 7 days / this month) aligned with "now" during live refreshes.
const resolveActiveRange = () => {
  if (isMonthFilter.value && currentMonthOffset.value === 0) {
    return {
      from: startOfDay(startOfMonth(new Date())),
      to: endOfDay(new Date()),
    };
  }

  if (!isMonthFilter.value && selectedDaysBefore.value !== null) {
    const to = endOfDay(new Date());
    return {
      from: startOfDay(subDays(to, Number(selectedDaysBefore.value))),
      to,
    };
  }

  if (!selectedFrom.value || !selectedTo.value) return null;
  return { from: selectedFrom.value, to: selectedTo.value };
};

const fetchProductivity = async () => {
  const range = resolveActiveRange();
  if (!range) return;

  try {
    const data = await run(signal =>
      ReportsAPI.getAgentProductivity({
        from: getUnixTime(range.from),
        to: getUnixTime(range.to),
        projectId: selectedProjectId.value,
        signal,
      }).then(response => camelcaseKeys(response.data, { deep: true }))
    );
    if (data) productivity.value = data;
  } catch {
    // Keep the last figures on screen; the next live refresh tries again.
  }
};

const { startRefetching } = useLiveRefresh(fetchProductivity);

const handleProjectChange = ({ value }) => {
  toggleProjectMenu(false);
  selectedProjectId.value = value;
  fetchProductivity();
};

const handleRangeTypeChange = type => {
  isMonthFilter.value = type === 'month';
};

const handleMonthOffsetChange = offset => {
  currentMonthOffset.value = offset;
};

watch(
  () => [selectedFrom.value, selectedTo.value],
  ([from, to]) => {
    if (from && to) fetchProductivity();
  }
);

onMounted(() => {
  if (!projects.value.length) store.dispatch('projects/get');
  startRefetching();
});
</script>

<template>
  <div class="flex max-w-full flex-row flex-wrap">
    <MetricCard
      class="min-w-0"
      :header="t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.HEADER')"
      :is-loading="isLoading"
      :loading-message="
        t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.LOADING_MESSAGE')
      "
    >
      <template #control>
        <div
          v-if="projects.length"
          v-on-clickaway="() => toggleProjectMenu(false)"
          class="relative flex items-center group z-50"
        >
          <Button
            sm
            slate
            faded
            :label="selectedProjectLabel"
            class="rounded-md group-hover:bg-n-alpha-2"
            @click="toggleProjectMenu()"
          />
          <DropdownMenu
            v-if="showProjectMenu"
            :menu-items="projectMenuItems"
            class="mt-1 end-0 top-full"
            @action="handleProjectChange"
          />
        </div>
        <HeatmapDateRangeSelector
          v-model:from="selectedFrom"
          v-model:to="selectedTo"
          v-model:days-num="selectedDaysBefore"
          default-range="last_30_days"
          @range-type-change="handleRangeTypeChange"
          @month-offset-change="handleMonthOffsetChange"
        />
      </template>
      <div v-if="productivity" class="flex flex-col w-full min-w-0 gap-3">
        <p class="mb-0 text-body-main text-n-slate-11">{{ scoreNote }}</p>
        <AgentProductivityTable :agents="productivity.agents" />
      </div>
    </MetricCard>
  </div>
</template>
