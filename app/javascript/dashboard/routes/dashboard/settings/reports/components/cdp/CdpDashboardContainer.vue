<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import camelcaseKeys from 'camelcase-keys';
import endOfDay from 'date-fns/endOfDay';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import getUnixTime from 'date-fns/getUnixTime';
import parseISO from 'date-fns/parseISO';
import startOfDay from 'date-fns/startOfDay';
import startOfMonth from 'date-fns/startOfMonth';
import subDays from 'date-fns/subDays';

import ReportsAPI from 'dashboard/api/reports';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import BarChart from 'shared/components/charts/BarChart.vue';
import HeatmapDateRangeSelector from '../heatmaps/HeatmapDateRangeSelector.vue';
import MetricCard from '../overview/MetricCard.vue';
import {
  DELTA_TONES,
  buildDailyChannelChart,
  formatDeltaPercent,
  formatDuration,
  formatHourRange,
  getAgentLoadPercent,
  getDeltaTone,
  getWeekdayName,
  isAgentNearLimit,
} from '../../helpers/cdpDashboardHelper';

const KPIS = [
  {
    key: 'totalChats',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.KPIS.TOTAL_CHATS',
  },
  {
    key: 'incomingMessages',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.KPIS.INCOMING_MESSAGES',
  },
  {
    key: 'outgoingMessages',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.KPIS.OUTGOING_MESSAGES',
  },
  {
    key: 'firstResponseTime',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.KPIS.FIRST_RESPONSE_TIME',
    duration: true,
  },
];

const DELTA_TONE_CLASSES = {
  [DELTA_TONES.BETTER]: 'text-n-teal-10',
  [DELTA_TONES.WORSE]: 'text-n-ruby-9',
  [DELTA_TONES.NEUTRAL]: 'text-n-slate-11',
};

// Stack order, bottom first: LINE in the accent colour, Facebook in ink, the rest in grey.
const CHANNEL_SERIES = [
  {
    key: 'line',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.LINE',
    color: 'rgb(var(--iris-9))',
  },
  {
    key: 'facebook',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.FACEBOOK',
    color: 'rgb(var(--slate-12))',
  },
  {
    key: 'others',
    label: 'OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.OTHERS',
    color: 'rgb(var(--slate-7))',
  },
];

const CHANNEL_LEGEND_CLASSES = {
  line: 'bg-n-iris-9',
  facebook: 'bg-n-slate-12',
  others: 'bg-n-slate-7',
};

const DAILY_CHART_HEIGHT = 250;

const store = useStore();
const { t, locale } = useI18n();
const { run, isPending } = useAbortableRequest();

const projects = useMapGetter('projects/getProjects');

const dashboard = ref(null);
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

const isLoading = computed(() => isPending.value && !dashboard.value);

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

const fetchDashboard = async () => {
  const range = resolveActiveRange();
  if (!range) return;

  try {
    const data = await run(signal =>
      ReportsAPI.getCdpDashboard({
        from: getUnixTime(range.from),
        to: getUnixTime(range.to),
        projectId: selectedProjectId.value,
        signal,
      }).then(response => camelcaseKeys(response.data, { deep: true }))
    );
    if (data) dashboard.value = data;
  } catch {
    // Keep the last figures on screen; the next live refresh tries again.
  }
};

const { startRefetching } = useLiveRefresh(fetchDashboard);

const comparedWith = computed(() => {
  if (!dashboard.value) return '';

  const { previousSince, previousUntil } = dashboard.value.period;
  const range = `${format(fromUnixTime(previousSince), 'dd/MM')} – ${format(
    fromUnixTime(previousUntil - 1),
    'dd/MM/yyyy'
  )}`;
  return t('OVERVIEW_REPORTS.CDP_DASHBOARD.COMPARED_WITH', { range });
});

const formatKpiValue = (kpi, value) => {
  if (kpi.duration) return formatDuration(value);
  return value.toLocaleString(locale.value);
};

const kpiCards = computed(() =>
  KPIS.map(kpi => {
    const { current, previous, deltaPercent } = dashboard.value.kpis[kpi.key];
    return {
      key: kpi.key,
      label: t(kpi.label),
      value: formatKpiValue(kpi, current),
      previous: formatKpiValue(kpi, previous),
      delta: formatDeltaPercent(deltaPercent),
      toneClass: DELTA_TONE_CLASSES[getDeltaTone(kpi.key, deltaPercent)],
    };
  })
);

const channelSeries = computed(() =>
  CHANNEL_SERIES.map(series => ({
    ...series,
    label: t(series.label),
  }))
);

const hasDailyChats = computed(() =>
  dashboard.value.dailyChannels.some(day => day.total > 0)
);

const dailyChart = computed(() =>
  buildDailyChannelChart(dashboard.value.dailyChannels, channelSeries.value)
);

const agentLoad = computed(() =>
  dashboard.value.agentLoad.map(agent => ({
    ...agent,
    percent: getAgentLoadPercent(agent),
    barClass: isAgentNearLimit(agent) ? 'bg-n-ruby-9' : 'bg-n-slate-12',
  }))
);

const intervalCards = computed(() => {
  const summary = dashboard.value.intervalSummary;
  if (!summary.total) return [];

  const { peakHour, busiestDay, busiestWeekday, outsideBusinessHours } =
    summary;
  return [
    {
      key: 'peakHour',
      label: t('OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.PEAK_HOUR'),
      value: formatHourRange(peakHour.hour),
      detail: t(
        'OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.PEAK_HOUR_DETAIL',
        {
          count: peakHour.count,
          total: summary.total,
        }
      ),
    },
    {
      key: 'busiestDay',
      label: t('OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.BUSIEST_DAY'),
      value: format(parseISO(busiestDay.date), 'dd/MM (EEE)'),
      detail: t(
        'OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.BUSIEST_DAY_DETAIL',
        {
          count: busiestDay.count,
          weekday: getWeekdayName(busiestWeekday.weekday, locale.value),
        }
      ),
    },
    {
      key: 'outsideBusinessHours',
      label: t(
        'OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.OUTSIDE_BUSINESS_HOURS'
      ),
      value: `${outsideBusinessHours.percent}%`,
      detail: t(
        'OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.OUTSIDE_BUSINESS_HOURS_DETAIL',
        {
          count: outsideBusinessHours.count,
          total: summary.total,
        }
      ),
    },
  ];
});

const handleProjectChange = ({ value }) => {
  toggleProjectMenu(false);
  selectedProjectId.value = value;
  fetchDashboard();
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
    if (from && to) fetchDashboard();
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
      :header="t('OVERVIEW_REPORTS.CDP_DASHBOARD.HEADER')"
      :is-loading="isLoading"
      :loading-message="t('OVERVIEW_REPORTS.CDP_DASHBOARD.LOADING_MESSAGE')"
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
          @range-type-change="handleRangeTypeChange"
          @month-offset-change="handleMonthOffsetChange"
        />
      </template>
      <div v-if="dashboard" class="flex flex-col w-full min-w-0 gap-6">
        <p class="mb-0 text-body-main text-n-slate-11">{{ comparedWith }}</p>

        <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <div
            v-for="card in kpiCards"
            :key="card.key"
            class="flex flex-col gap-1 p-4 rounded-lg outline outline-1 outline-n-container"
          >
            <span class="text-label text-n-slate-11">{{ card.label }}</span>
            <span class="text-3xl text-n-slate-12 tabular-nums">
              {{ card.value }}
            </span>
            <span class="text-label-small tabular-nums" :class="card.toneClass">
              {{ card.delta }}
            </span>
            <span class="text-label-small text-n-slate-11 tabular-nums">
              {{
                t('OVERVIEW_REPORTS.CDP_DASHBOARD.PREVIOUS_VALUE', {
                  value: card.previous,
                })
              }}
            </span>
          </div>
        </div>

        <div
          class="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]"
        >
          <div class="flex flex-col min-w-0 gap-3">
            <h6 class="mb-0 text-heading-3 text-n-slate-12">
              {{ t('OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.HEADER') }}
            </h6>
            <BarChart
              v-if="hasDailyChats"
              :data="dailyChart"
              :aria-label="
                t('OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.ARIA_LABEL')
              "
              :height="DAILY_CHART_HEIGHT"
              stacked
              show-values
            />
            <span v-else class="text-body-main text-n-slate-10">
              {{ t('OVERVIEW_REPORTS.CDP_DASHBOARD.DAILY_CHANNELS.NO_DATA') }}
            </span>
            <div class="flex flex-wrap gap-4 text-label-small text-n-slate-11">
              <span
                v-for="series in channelSeries"
                :key="series.key"
                class="flex items-center gap-1.5"
              >
                <span
                  class="size-2.5 rounded-sm"
                  :class="CHANNEL_LEGEND_CLASSES[series.key]"
                />
                {{ series.label }}
              </span>
            </div>
          </div>

          <div class="flex flex-col min-w-0 gap-3">
            <h6 class="mb-0 text-heading-3 text-n-slate-12">
              {{ t('OVERVIEW_REPORTS.CDP_DASHBOARD.AGENT_LOAD.HEADER') }}
            </h6>
            <div
              v-for="agent in agentLoad"
              :key="agent.id"
              class="grid grid-cols-[minmax(0,7rem)_1fr_auto] items-center gap-3 py-1.5 border-b border-n-weak"
            >
              <span class="truncate text-body-main text-n-slate-12">
                {{ agent.name }}
              </span>
              <div class="h-2.5 rounded-sm bg-n-slate-3">
                <div
                  class="h-full rounded-sm"
                  :class="agent.barClass"
                  :style="{ width: `${agent.percent}%` }"
                />
              </div>
              <span class="text-label text-n-slate-12 tabular-nums">
                {{
                  t('OVERVIEW_REPORTS.CDP_DASHBOARD.AGENT_LOAD.COUNT', {
                    count: agent.assignedCount,
                    limit: agent.limit,
                  })
                }}
              </span>
            </div>
            <span
              v-if="!agentLoad.length"
              class="text-body-main text-n-slate-10"
            >
              {{ t('OVERVIEW_REPORTS.CDP_DASHBOARD.AGENT_LOAD.NO_AGENTS') }}
            </span>
          </div>
        </div>

        <div
          v-if="intervalCards.length"
          class="grid grid-cols-1 gap-4 md:grid-cols-3"
        >
          <div
            v-for="card in intervalCards"
            :key="card.key"
            class="flex flex-col gap-1 p-4 rounded-lg outline outline-1 outline-n-container"
          >
            <span class="text-label text-n-slate-11">{{ card.label }}</span>
            <span class="text-2xl text-n-slate-12 tabular-nums">
              {{ card.value }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ card.detail }}
            </span>
          </div>
        </div>
        <span v-else class="text-body-main text-n-slate-10">
          {{ t('OVERVIEW_REPORTS.CDP_DASHBOARD.INTERVAL_SUMMARY.NO_DATA') }}
        </span>
      </div>
    </MetricCard>
  </div>
</template>
