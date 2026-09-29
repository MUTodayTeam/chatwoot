<script setup>
import { useI18n } from 'vue-i18n';
import { formatDuration } from '../../helpers/cdpDashboardHelper';

// Touch-based productivity (spec 10): one row per agent, highest score first
defineProps({
  agents: {
    type: Array,
    default: () => [],
  },
});

const { t, locale } = useI18n();

const COLUMNS = [
  { key: 'agent', label: 'AGENT', align: 'text-start' },
  { key: 'resolved', label: 'RESOLVED', align: 'text-end' },
  { key: 'assisted', label: 'ASSISTED', align: 'text-end' },
  { key: 'transferOut', label: 'TRANSFER_OUT', align: 'text-end' },
  { key: 'transferIn', label: 'TRANSFER_IN', align: 'text-end' },
  { key: 'contribution', label: 'CONTRIBUTION', align: 'text-start' },
  { key: 'handleTime', label: 'HANDLE_TIME', align: 'text-end' },
  { key: 'firstResponse', label: 'FIRST_RESPONSE', align: 'text-end' },
  { key: 'score', label: 'SCORE', align: 'text-end' },
];

// 1.0, 0.5 and 0.25 as the weights make them
const formatScore = value =>
  new Intl.NumberFormat(locale.value, {
    minimumFractionDigits: 1,
    maximumFractionDigits: 2,
  }).format(value);

const FULL_PERCENT = 100;

const contributionLabel = agent =>
  t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.CONTRIBUTION_LABEL', {
    resolved: agent.contributionPercent,
    assisted: FULL_PERCENT - agent.contributionPercent,
  });
</script>

<template>
  <div
    class="w-full max-w-full overflow-x-auto rounded-lg border border-n-weak"
  >
    <table
      class="min-w-full border-separate border-spacing-0 text-sm"
      :aria-label="t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.ARIA_LABEL')"
    >
      <thead>
        <tr>
          <th
            v-for="column in COLUMNS"
            :key="column.key"
            scope="col"
            class="border-b border-n-weak bg-n-solid-2 px-3 py-2 font-medium text-n-slate-11 whitespace-nowrap"
            :class="column.align"
          >
            {{
              t(`OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.COLUMNS.${column.label}`)
            }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!agents.length">
          <td
            :colspan="COLUMNS.length"
            class="px-3 py-8 text-center text-n-slate-11"
          >
            {{ t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.NO_AGENTS') }}
          </td>
        </tr>
        <template v-else>
          <tr v-for="agent in agents" :key="agent.id">
            <th
              scope="row"
              class="min-w-40 border-b border-n-weak px-3 py-2 text-start font-medium text-n-slate-12"
            >
              {{ agent.name }}
            </th>
            <td class="border-b border-n-weak px-3 py-2 text-end tabular-nums">
              {{ agent.resolved }}
            </td>
            <td class="border-b border-n-weak px-3 py-2 text-end tabular-nums">
              {{ agent.assisted }}
            </td>
            <td
              class="border-b border-n-weak px-3 py-2 text-end tabular-nums whitespace-nowrap"
            >
              {{ agent.transferOut }}
              <span v-if="agent.penalty" class="text-n-ruby-11">
                {{
                  t('OVERVIEW_REPORTS.AGENT_PRODUCTIVITY.PENALTY', {
                    penalty: formatScore(agent.penalty),
                  })
                }}
              </span>
            </td>
            <td class="border-b border-n-weak px-3 py-2 text-end tabular-nums">
              {{ agent.transferIn }}
            </td>
            <td class="min-w-40 border-b border-n-weak px-3 py-2">
              <div
                class="flex h-2 w-full overflow-hidden rounded bg-n-slate-3"
                role="img"
                :aria-label="contributionLabel(agent)"
              >
                <div
                  class="h-full bg-n-slate-12"
                  :style="{ width: `${agent.contributionPercent}%` }"
                />
                <div class="h-full flex-1 bg-n-slate-7" />
              </div>
            </td>
            <td class="border-b border-n-weak px-3 py-2 text-end tabular-nums">
              {{ formatDuration(agent.avgHandleTime) }}
            </td>
            <td class="border-b border-n-weak px-3 py-2 text-end tabular-nums">
              {{ formatDuration(agent.avgFirstResponse) }}
            </td>
            <td
              class="border-b border-n-weak px-3 py-2 text-end font-semibold tabular-nums text-n-slate-12"
            >
              {{ formatScore(agent.score) }}
            </td>
          </tr>
        </template>
      </tbody>
    </table>
  </div>
</template>
