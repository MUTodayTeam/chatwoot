<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { messageStamp } from 'shared/helpers/timeHelper';
import { dayLabel } from 'dashboard/helper/dayDivider';
import {
  TIMELINE_TONE_CLASSES,
  buildConversationTimeline,
} from 'dashboard/helper/conversationTimeline';

const props = defineProps({
  chat: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const inboxGetter = useMapGetter('inboxes/getInbox');

const events = computed(() => {
  const inbox = inboxGetter.value(props.chat.inbox_id);
  return buildConversationTimeline({
    messages: props.chat.messages,
    createdAt: props.chat.created_at,
    arrivedText: t('CONVERSATION_SIDEBAR.TIMELINE.ARRIVED', {
      channel: inbox.name,
    }),
  });
});

const when = time =>
  `${dayLabel(time, t('CONVERSATION.DAY_DIVIDER.TODAY'))} ${messageStamp(time)}`;
</script>

<template>
  <ol class="flex flex-col gap-2.5 m-0 mx-4 mb-2 border-s-2 border-n-weak">
    <li v-for="event in events" :key="event.id" class="relative ps-3">
      <span
        class="absolute top-1.5 -start-[0.3125rem] size-2"
        :class="TIMELINE_TONE_CLASSES[event.tone]"
      />
      <p class="m-0 text-body-main text-n-slate-12">{{ event.text }}</p>
      <p class="m-0 text-label-small text-n-slate-11">
        {{ when(event.createdAt) }}
      </p>
    </li>
  </ol>
</template>
