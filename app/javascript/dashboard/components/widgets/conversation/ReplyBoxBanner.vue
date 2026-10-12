<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import ConversationApi from 'dashboard/api/inbox/conversation';
import {
  LIFECYCLE_STATUS,
  getLifecycleStatus,
} from 'dashboard/helper/conversationLifecycle';

import Banner from 'dashboard/components/ui/Banner.vue';
import BotModeBanner from 'dashboard/components-next/Conversation/BotModeBanner.vue';

const props = defineProps({
  message: {
    type: String,
    default: '',
  },
  isOnPrivateNote: {
    type: Boolean,
    default: false,
  },
});

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');

const assignedAgent = computed(() => currentChat.value?.meta?.assignee);

const showSelfAssignBanner = computed(
  () =>
    props.message !== '' &&
    !props.isOnPrivateNote &&
    (!assignedAgent.value || assignedAgent.value.id !== currentUser.value?.id)
);

// Pending with an agent bot or a Captain assistant as the assignee (spec §5 Bot banner)
const showBotHandoffBanner = computed(
  () =>
    !!currentChat.value &&
    getLifecycleStatus(currentChat.value) === LIFECYCLE_STATUS.BOT
);

const isTakingOver = ref(false);

const selfAssignConversation = async conversationId => {
  const { data } = await ConversationApi.assignAgent({
    conversationId,
    agentId: currentUser.value.id,
    assigneeType: 'User',
  });
  await store.dispatch('setCurrentChatAssignee', {
    conversationId,
    assignee: data,
    assigneeType: 'User',
  });
};

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation(currentChat.value.id);
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

// The bar only shows while an agent bot or a Captain assistant holds the chat, so taking
// it over always assigns it to the agent. Comparing ids would not do: the assistant's id
// comes from another table and can equal the agent's. The assignment opens the pending
// conversation on the server, so the status is only mirrored here.
const onClickBotHandoff = async () => {
  const conversationId = currentChat.value.id;
  isTakingOver.value = true;
  try {
    await selfAssignConversation(conversationId);
    store.commit('CHANGE_CONVERSATION_STATUS', {
      conversationId,
      status: 'open',
      snoozedUntil: null,
    });
    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  } finally {
    isTakingOver.value = false;
  }
};
</script>

<template>
  <Banner
    v-if="showSelfAssignBanner && !showBotHandoffBanner"
    action-button-variant="ghost"
    color-scheme="secondary"
    class="mx-2 mb-2 rounded-lg !py-2"
    :banner-message="$t('CONVERSATION.NOT_ASSIGNED_TO_YOU')"
    has-action-button
    :action-button-label="$t('CONVERSATION.ASSIGN_TO_ME')"
    @primary-action="onClickSelfAssign"
  />
  <BotModeBanner
    v-if="showBotHandoffBanner"
    :is-loading="isTakingOver"
    @take-over="onClickBotHandoff"
  />
</template>
