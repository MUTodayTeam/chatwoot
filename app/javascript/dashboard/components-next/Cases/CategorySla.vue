<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { slaParts } from 'dashboard/helper/caseCategoryHelper';

// "15 min / 1 d": respond within, then resolve within
const props = defineProps({
  respondMinutes: {
    type: Number,
    default: null,
  },
  resolveMinutes: {
    type: Number,
    default: null,
  },
});

const { t } = useI18n();

const format = minutes => {
  const parts = slaParts(minutes);
  if (!parts) return t('CASE_CATEGORIES.SLA.NONE');
  return t(`CASE_CATEGORIES.SLA.${parts.unit.toUpperCase()}`, {
    n: parts.count,
  });
};

const hasSla = computed(
  () => props.respondMinutes != null || props.resolveMinutes != null
);
</script>

<template>
  <span class="whitespace-nowrap">
    <template v-if="hasSla">
      {{
        t('CASE_CATEGORIES.SLA.PAIR', {
          respond: format(respondMinutes),
          resolve: format(resolveMinutes),
        })
      }}
    </template>
    <template v-else>{{ t('CASE_CATEGORIES.SLA.NONE') }}</template>
  </span>
</template>
