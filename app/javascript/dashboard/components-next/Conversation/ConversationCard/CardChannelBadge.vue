<script setup>
import { computed } from 'vue';
import { getChannelBadge } from 'dashboard/helper/conversationListRow';

const props = defineProps({
  chat: { type: Object, required: true },
});

const badge = computed(() =>
  getChannelBadge(props.chat.meta?.channel, props.chat.additional_attributes)
);
</script>

<template>
  <span
    v-if="badge"
    class="inline-grid place-items-center size-4 rounded-sm bg-n-background outline outline-1 outline-n-slate-12 text-xxxs font-extrabold leading-none text-n-slate-12"
  >
    {{ badge }}
  </span>
</template>
