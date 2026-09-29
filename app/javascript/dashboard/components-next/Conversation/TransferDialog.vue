<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useIntervalFn } from '@vueuse/core';
import getUnixTime from 'date-fns/getUnixTime';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import ConversationApi from 'dashboard/api/inbox/conversation';
import { formatDuration } from 'dashboard/routes/dashboard/settings/reports/helpers/cdpDashboardHelper';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// Transfer (spec 7.2): hand the conversation to the project's transfer team with a reason
const props = defineProps({
  conversationId: {
    type: Number,
    required: true,
  },
});

// The order agents see them in; "scope" is the default (spec 7.2)
const TRANSFER_REASONS = ['scope', 'escalate', 'shift', 'general'];
const DEFAULT_REASON = 'scope';
const NOTE_MAX_LENGTH = 500;
const CLOCK_INTERVAL_MS = 1000;

const { t } = useI18n();
const store = useStore();
const { run, isPending } = useAbortableRequest();
const currentUserId = useMapGetter('getCurrentUserID');
// Ticks only while the dialog is open, for the handling time in the credit note
const now = ref(new Date());
const { pause: pauseClock, resume: resumeClock } = useIntervalFn(
  () => {
    now.value = new Date();
  },
  CLOCK_INTERVAL_MS,
  { immediate: false, immediateCallback: true }
);

const dialogRef = ref(null);
const transfer = ref(null);
const reason = ref(DEFAULT_REASON);
const note = ref('');
const transferringTo = ref(null);

const agents = computed(() => transfer.value?.agents ?? []);
const team = computed(() => transfer.value?.team);

const creditNote = computed(() => {
  const handler = transfer.value?.handler;
  if (!handler) return t('CONVERSATION.TRANSFER.CREDIT.NEW_ONLY');

  const time = formatDuration(getUnixTime(now.value) - handler.started_at);
  if (handler.user_id === currentUserId.value) {
    return t('CONVERSATION.TRANSFER.CREDIT.SELF', { time });
  }
  return t('CONVERSATION.TRANSFER.CREDIT.OTHER', { time });
});

const emptyMessage = computed(() =>
  team.value
    ? t('CONVERSATION.TRANSFER.NO_AGENTS', { team: team.value.name })
    : t('CONVERSATION.TRANSFER.NO_TEAM')
);

const fetchTransfer = async () => {
  try {
    const response = await run(signal =>
      ConversationApi.getTransfer(props.conversationId, { signal })
    );
    // A newer request replaced this one
    if (response) transfer.value = response.data;
  } catch (error) {
    useAlert(t('CONVERSATION.TRANSFER.FETCH_ERROR'));
  }
};

const open = () => {
  transfer.value = null;
  reason.value = DEFAULT_REASON;
  note.value = '';
  fetchTransfer();
  resumeClock();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

defineExpose({ open, close });

// Picking an agent hands the conversation over, as Assign does
const transferTo = async agent => {
  if (transferringTo.value) return;

  transferringTo.value = agent.id;
  try {
    await store.dispatch('transferConversation', {
      conversationId: props.conversationId,
      assigneeId: agent.id,
      reason: reason.value,
      note: note.value.trim(),
    });
    useAlert(t('CONVERSATION.TRANSFER.SUCCESS', { name: agent.name }));
    close();
  } catch (error) {
    useAlert(error.message || t('CONVERSATION.TRANSFER.ERROR'));
  } finally {
    transferringTo.value = null;
  }
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CONVERSATION.TRANSFER.TITLE')"
    :description="
      team ? t('CONVERSATION.TRANSFER.DESCRIPTION', { team: team.name }) : ''
    "
    :show-confirm-button="false"
    :cancel-button-label="t('CONVERSATION.TRANSFER.CANCEL')"
    @close="pauseClock"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div class="flex flex-col gap-2">
        <span class="text-label text-n-slate-12">
          {{ t('CONVERSATION.TRANSFER.REASON') }}
        </span>
        <div class="flex flex-wrap gap-2" role="radiogroup">
          <Button
            v-for="option in TRANSFER_REASONS"
            :key="option"
            :label="t(`CONVERSATION.TRANSFER.REASONS.${option}`)"
            :variant="reason === option ? 'solid' : 'faded'"
            color="slate"
            size="sm"
            type="button"
            role="radio"
            :aria-checked="reason === option"
            @click="reason = option"
          />
        </div>
      </div>

      <TextArea
        v-model="note"
        :label="t('CONVERSATION.TRANSFER.NOTE')"
        :placeholder="t('CONVERSATION.TRANSFER.NOTE_PLACEHOLDER')"
        :max-length="NOTE_MAX_LENGTH"
      />

      <p
        class="px-3 py-2 mb-0 rounded-lg bg-n-alpha-1 text-body-main text-n-slate-11"
      >
        {{ creditNote }}
      </p>

      <div class="flex flex-col overflow-y-auto max-h-[40vh] min-h-24">
        <div v-if="isPending && !transfer" class="flex justify-center py-6">
          <Spinner />
        </div>
        <p
          v-else-if="!agents.length"
          class="py-6 mb-0 text-center text-body-main text-n-slate-11"
        >
          {{ emptyMessage }}
        </p>
        <template v-else>
          <button
            v-for="agent in agents"
            :key="agent.id"
            type="button"
            class="flex items-center w-full gap-3 px-1 py-2.5 border-b border-n-weak text-start hover:bg-n-alpha-1 disabled:opacity-60"
            :disabled="Boolean(transferringTo)"
            @click="transferTo(agent)"
          >
            <Avatar
              :name="agent.name"
              :src="agent.thumbnail"
              :size="28"
              :status="agent.availability_status"
            />
            <span
              class="flex-1 min-w-0 truncate text-body-main text-n-slate-12"
            >
              {{ agent.available_name || agent.name }}
            </span>
            <Spinner v-if="transferringTo === agent.id" class="size-4" />
            <span v-else class="text-label-small text-n-slate-11">
              {{ t('CONVERSATION.TRANSFER.PICK') }}
            </span>
          </button>
        </template>
      </div>
    </div>
  </Dialog>
</template>
