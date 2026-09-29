<script setup>
import { I18nT, useI18n } from 'vue-i18n';

defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['takeOver']);

const { t } = useI18n();
</script>

<template>
  <div
    class="flex items-center gap-2.5 px-5 py-2 bg-n-slate-12 text-n-slate-1 text-label-small"
  >
    <span class="flex-shrink-0 size-2 bg-n-ruby-9 animate-pulse" />
    <I18nT keypath="CONVERSATION.BOT_MODE_BANNER.MESSAGE" tag="span">
      <template #takeOver>
        <button
          type="button"
          class="p-0 underline bg-transparent border-0 text-label-small text-n-slate-1 disabled:opacity-50"
          :disabled="isLoading"
          @click="emit('takeOver')"
        >
          {{ t('CONVERSATION.BOT_MODE_BANNER.TAKE_OVER') }}
        </button>
      </template>
    </I18nT>
  </div>
</template>
