<script setup>
import { computed } from 'vue';
import { getChannelBadge } from 'dashboard/helper/conversationListRow';

const props = defineProps({
  channelType: { type: String, default: '' },
});

const badge = computed(() => getChannelBadge(props.channelType));
</script>

<template>
  <span
    v-if="badge"
    class="inline-grid place-items-center size-4 rounded-sm bg-n-background outline outline-1 outline-n-slate-12 text-xxxs font-extrabold leading-none text-n-slate-12"
  >
    {{ badge }}
  </span>
</template>
