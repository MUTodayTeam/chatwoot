<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { caseStatusColor } from 'dashboard/helper/caseHelper';
import Label from 'dashboard/components-next/label/Label.vue';

// A case has no status of its own: this is its conversation's status
const props = defineProps({
  status: {
    type: String,
    required: true,
  },
});

const { t } = useI18n();

const title = computed(() => t(`CASES.STATUS.${props.status}`));
</script>

<template>
  <Label :label="title" :color="caseStatusColor(status)" compact />
</template>
