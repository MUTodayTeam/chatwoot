<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { caseSeverityColor } from 'dashboard/helper/caseHelper';
import Label from 'dashboard/components-next/label/Label.vue';

const props = defineProps({
  severity: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const title = computed(() => t(`CASES.SEVERITY.${props.severity}`));
</script>

<template>
  <Label :label="title" :color="caseSeverityColor(severity)" compact />
</template>
