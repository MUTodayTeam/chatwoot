<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  count: { type: Number, required: true },
});

const { t } = useI18n();

const displayCount = computed(() =>
  props.count > 9 ? t('CHAT_LIST.UNREAD_COUNT_OVERFLOW') : props.count
);
</script>

<template>
  <span
    v-if="count > 0"
    class="bg-n-teal-9 rounded-full h-4 min-w-4 max-w-5 px-1 w-fit font-medium text-xxs leading-3 text-white inline-grid place-items-center flex-shrink-0 ring-2 ring-n-background"
  >
    {{ displayCount }}
  </span>
  <span v-else />
</template>
