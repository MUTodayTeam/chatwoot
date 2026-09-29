<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
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

const assignedAgent = computed({
  get() {
    return currentChat.value?.meta?.assignee;
  },
  set(agent) {
    const agentId = agent ? agent.id : null;
    store.dispatch('setCurrentChatAssignee', {
      conversationId: currentChat.value?.id,
      assignee: agent,
      assigneeType: agent ? 'User' : null,
    });
    store.dispatch('assignAgent', {
      conversationId: currentChat.value?.id,
      agentId,
    });
  },
});

const hasMessage = computed(() => props.message !== '');
const isUserTyping = computed(() => hasMessage.value && !props.isOnPrivateNote);
const isUnassigned = computed(() => !assignedAgent.value);
const isAssignedToOtherAgent = computed(
  () => assignedAgent.value?.id !== currentUser.value?.id
);

const showSelfAssignBanner = computed(() => {
  return (
    isUserTyping.value && (isUnassigned.value || isAssignedToOtherAgent.value)
  );
});

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

// Pending with an agent bot or a Captain assistant as the assignee (spec §5 Bot banner)
const showBotHandoffBanner = computed(
  () =>
    !!currentChat.value &&
    getLifecycleStatus(currentChat.value) === LIFECYCLE_STATUS.BOT
);

const isTakingOver = ref(false);

const selfAssignConversation = async () => {
  const { avatar_url, ...rest } = currentUser.value || {};
  assignedAgent.value = { ...rest, thumbnail: avatar_url };
};

const needsAssignmentToCurrentUser = computed(() => {
  return isUnassigned.value || isAssignedToOtherAgent.value;
});

const onClickSelfAssign = async () => {
  try {
    await selfAssignConversation();
    useAlert(t('CONVERSATION.CHANGE_AGENT'));
  } catch (error) {
    useAlert(t('CONVERSATION.CHANGE_AGENT_FAILED'));
  }
};

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: 'open',
  });
};

const onClickBotHandoff = async () => {
  isTakingOver.value = true;
  try {
    const shouldAssignToCurrentUser =
      isAgentBotOwned.value || needsAssignmentToCurrentUser.value;

    await reopenConversation();

    if (shouldAssignToCurrentUser) {
      await selfAssignConversation();
    }

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
