<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CasesAPI from 'dashboard/api/cases';
import { useConversationRoutePath } from 'dashboard/composables/useConversationRoutePath';
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import ConversationContextMenu from 'dashboard/components/widgets/conversation/contextMenu/Index.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: { type: [String, Number], required: true },
  conversationId: { type: [String, Number], required: true },
});

// The last chats that ended (Solved or Closed), each with the topic picked when it was solved
const FINISHED_STATUSES = ['resolved', 'closed'];
const FINISHED_LIMIT = 6;

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { buildConversationPath } = useConversationRoutePath();

const currentChat = useMapGetter('getSelectedChat');
const uiFlags = useMapGetter('contactConversations/getUIFlags');

const contactGetter = useMapGetter('contacts/getContact');
const inboxGetter = useMapGetter('inboxes/getInbox');

const activeInbox = useMapGetter('getSelectedInbox');
const inboxesList = useMapGetter('inboxes/getInboxes');
const showInboxName = computed(
  () => !activeInbox.value && inboxesList.value.length > 1
);

const contactConversationGetter = useMapGetter(
  'contactConversations/getContactConversation'
);
const conversations = computed(() =>
  contactConversationGetter.value(props.contactId)
);

const previousConversations = computed(() =>
  conversations.value
    .filter(
      c =>
        c.id !== Number(props.conversationId) &&
        FINISHED_STATUSES.includes(c.status)
    )
    .sort((a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0))
    .slice(0, FINISHED_LIMIT)
);

const topics = ref({});

const fetchTopics = async contactId => {
  try {
    const { data } = await CasesAPI.get({ contact_id: contactId });
    topics.value = Object.fromEntries(
      data.payload.map(kase => [
        kase.conversation.id,
        kase.category?.c3 || t('CONTACT_PANEL.CONVERSATIONS.TOPIC_OTHER'),
      ])
    );
  } catch (error) {
    topics.value = {};
  }
};

const activeContextChat = ref(null);
const showContextMenu = ref(false);
const contextMenu = ref({ x: null, y: null });

const conversationPath = computed(() => {
  if (!activeContextChat.value) return '';
  return buildConversationPath(activeContextChat.value.id);
});

const onCardClick = (conversation, e) => {
  const path = buildConversationPath(conversation.id);
  if (!path) return;

  if (e.metaKey || e.ctrlKey) {
    e.preventDefault();
    window.open(
      `${window.chatwootConfig.hostURL}${path}`,
      '_blank',
      'noopener,noreferrer'
    );
    return;
  }

  router.push({ path });
};

const openContextMenu = (conversation, e) => {
  e.preventDefault();
  activeContextChat.value = conversation;
  contextMenu.value.x = e.pageX || e.clientX;
  contextMenu.value.y = e.pageY || e.clientY;
  showContextMenu.value = true;
};

const closeContextMenu = () => {
  showContextMenu.value = false;
  contextMenu.value.x = null;
  contextMenu.value.y = null;
  activeContextChat.value = null;
};

watch(
  () => props.contactId,
  (newId, oldId) => {
    if (newId && newId !== oldId) {
      showContextMenu.value = false;
      activeContextChat.value = null;
      store.dispatch('contactConversations/get', newId);
      fetchTopics(newId);
    }
  }
);

onMounted(() => {
  store.dispatch('contactConversations/get', props.contactId);
  fetchTopics(props.contactId);
});
</script>

<template>
  <div v-if="!uiFlags.isFetching" class="">
    <div v-if="!previousConversations.length" class="no-label-message px-4 p-3">
      <span>
        {{ $t('CONTACT_PANEL.CONVERSATIONS.NO_RECORDS_FOUND') }}
      </span>
    </div>
    <div v-else class="contact-conversation--list">
      <div v-for="conversation in previousConversations" :key="conversation.id">
        <ConversationCard
          :chat="conversation"
          :current-contact="contactGetter(conversation.meta?.sender?.id) || {}"
          :assignee="conversation.meta?.assignee || {}"
          :inbox="inboxGetter(conversation.inbox_id) || {}"
          :is-active-chat="currentChat.id === conversation.id"
          :show-inbox-name="showInboxName"
          hide-thumbnail
          compact
          @click="onCardClick(conversation, $event)"
          @contextmenu="openContextMenu(conversation, $event)"
        />
        <p
          v-if="topics[conversation.id]"
          class="m-0 px-4 pb-2 text-body-main text-n-slate-11 truncate"
        >
          {{
            t('CONTACT_PANEL.CONVERSATIONS.TOPIC', {
              topic: topics[conversation.id],
            })
          }}
        </p>
      </div>
    </div>
    <ContextMenu
      v-if="showContextMenu && activeContextChat"
      :x="contextMenu.x"
      :y="contextMenu.y"
      @close="closeContextMenu"
    >
      <ConversationContextMenu
        :status="activeContextChat.status"
        :inbox-id="activeContextChat.inbox_id"
        :priority="activeContextChat.priority"
        :chat-id="activeContextChat.id"
        :has-unread-messages="activeContextChat.unread_count > 0"
        :conversation-labels="activeContextChat.labels"
        :conversation-url="conversationPath"
        :allowed-options="['open-new-tab', 'copy-link']"
        @close="closeContextMenu"
      />
    </ContextMenu>
  </div>
  <div v-else class="flex items-center justify-center py-5">
    <Spinner />
  </div>
</template>

<style lang="scss" scoped>
.no-label-message {
  @apply text-n-slate-11 mb-4;
}
</style>
