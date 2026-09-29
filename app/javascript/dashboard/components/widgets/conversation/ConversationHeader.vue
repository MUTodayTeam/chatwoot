<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ReplyDeadlineControl from 'dashboard/components-next/Conversation/ReplyDeadlineControl.vue';
import StatusDropdown from 'dashboard/components-next/Conversation/StatusDropdown.vue';
import TransferDialog from 'dashboard/components-next/Conversation/TransferDialog.vue';
import AssignDialog from 'dashboard/components-next/Conversation/AssignDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { findProjectForInbox } from 'dashboard/helper/conversationListRow';
import {
  getAssigneeName,
  getHeaderTags,
} from 'dashboard/helper/conversationHeader';
import { useInbox } from 'dashboard/composables/useInbox';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();
const { uiSettings, updateUISettings } = useUISettings();

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

// Solved and Closed have no agent to transfer from; they reopen instead (spec 5, 7.4)
const FINISHED_STATUSES = [
  wootConstants.STATUS_TYPE.RESOLVED,
  wootConstants.STATUS_TYPE.CLOSED,
];
const isFinished = computed(() =>
  FINISHED_STATUSES.includes(currentChat.value.status)
);

const transferDialogRef = ref(null);
const assignDialogRef = ref(null);
const isReopening = ref(false);

const reopenConversation = async () => {
  isReopening.value = true;
  try {
    await store.dispatch('reopenConversation', {
      conversationId: currentChat.value.id,
    });
    useAlert(t('CONVERSATION.REOPEN.SUCCESS'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION.REOPEN.ERROR'));
  } finally {
    isReopening.value = false;
  }
};

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const project = computed(() =>
  findProjectForInbox(
    store.getters['projects/getProjects'],
    props.chat.inbox_id
  )
);

const headerTags = computed(() =>
  getHeaderTags({ inbox: inbox.value, project: project.value })
);

const assigneeName = computed(() => getAssigneeName(props.chat.meta?.assignee));

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

// The contact's picture is the way into the contact panel, replacing the
// floating switch that used to sit over the messages. Alt+O moved here with it.
const toggleContactPanel = () => {
  updateUISettings({
    is_contact_sidebar_open: !uiSettings.value.is_contact_sidebar_open,
    is_copilot_panel_open: false,
  });
};

useKeyboardEvents({
  'Alt+KeyO': { action: toggleContactPanel },
});

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-3 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-3 pt-3 pb-2 h-24 xl:h-12"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="me-2"
      />
      <button
        v-tooltip.bottom="$t('CONVERSATION.SIDEBAR.CONTACT')"
        type="button"
        class="flex-shrink-0 rounded-full outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
        :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
        :aria-pressed="Boolean(uiSettings.is_contact_sidebar_open)"
        @click="toggleContactPanel"
      >
        <Avatar
          :name="currentContact.name"
          :src="currentContact.thumbnail"
          :size="32"
          :status="currentContact.availability_status"
          hide-offline-status
        />
      </button>
      <div class="flex flex-col items-start min-w-0 ms-2 overflow-hidden">
        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <span
            class="text-sm font-medium truncate leading-tight text-n-slate-12"
          >
            {{ currentContact.name }}
          </span>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
          <!-- 1320px is the spec's breakpoint for folding chips (§16.1) -->
          <span
            v-for="tag in headerTags"
            :key="tag.key"
            class="hidden min-[1320px]:inline-block px-1.5 border border-n-weak rounded-sm text-label-small text-n-slate-11 truncate max-w-32 flex-shrink-0"
          >
            {{ tag.label }}
          </span>
        </div>

        <div
          class="flex items-center gap-1 overflow-hidden text-xs conversation--header--actions text-n-slate-11 text-ellipsis whitespace-nowrap"
        >
          <button
            type="button"
            class="truncate text-label-small text-n-slate-11 hover:text-n-slate-12 !p-0 cucursor-pointer"
            @click="copyConversationId"
          >
            {{ `#${chat.id}` }}
          </button>
          <template v-if="chat.case">
            <span>•</span>
            <span class="text-label-small text-n-ruby-11">
              {{ $t('CASES.HEADER_CHIP', { display: chat.case.display }) }}
            </span>
          </template>
          <template v-for="tag in headerTags" :key="tag.key">
            <span class="min-[1320px]:hidden">•</span>
            <span class="truncate min-[1320px]:hidden">{{ tag.label }}</span>
          </template>
          <span>•</span>
          <span class="truncate">
            {{
              assigneeName
                ? $t('CONVERSATION.HEADER.ASSIGNEE', { name: assigneeName })
                : $t('CONVERSATION.HEADER.NO_ASSIGNEE')
            }}
          </span>
          <span v-if="isSnoozed">•</span>
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <ReplyDeadlineControl :chat="chat" class="hidden md:flex" />
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <Button
        v-if="isFinished"
        :label="$t('CONVERSATION.REOPEN.BUTTON')"
        icon="i-lucide-rotate-ccw"
        variant="faded"
        color="slate"
        size="sm"
        :is-loading="isReopening"
        :disabled="isReopening"
        @click="reopenConversation"
      />
      <template v-else>
        <Button
          v-tooltip.top="$t('CONVERSATION.ASSIGN_DIALOG.TOOLTIP')"
          :label="$t('CONVERSATION.ASSIGN_DIALOG.BUTTON')"
          icon="i-lucide-user-round-plus"
          variant="faded"
          color="slate"
          size="sm"
          @click="assignDialogRef?.open()"
        />
        <AssignDialog
          ref="assignDialogRef"
          :conversation-id="currentChat.id"
          :inbox-id="currentChat.inbox_id"
        />
        <Button
          v-tooltip.top="$t('CONVERSATION.TRANSFER.TOOLTIP')"
          :label="$t('CONVERSATION.TRANSFER.BUTTON')"
          icon="i-lucide-arrow-right-left"
          variant="faded"
          color="slate"
          size="sm"
          @click="transferDialogRef?.open()"
        />
        <TransferDialog
          ref="transferDialogRef"
          :conversation-id="currentChat.id"
        />
      </template>
      <StatusDropdown />
      <MoreActions :conversation-id="currentChat.id" />
    </div>
  </div>
</template>
