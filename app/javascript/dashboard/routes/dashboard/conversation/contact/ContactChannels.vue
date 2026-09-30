<script setup>
import { computed, ref, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import ContactAPI from 'dashboard/api/contacts';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

// Channels come from the contact's conversations the user may see (the endpoint applies the permission
// filter), so an inbox the user cannot open never reaches the browser. The store only adds name and icon.
const accessibleInboxes = useMapGetter('inboxes/getInboxes');
const linkedInboxIds = ref([]);

// One row per inbox the contact has written to, however many times it did
const inboxes = computed(() =>
  accessibleInboxes.value.filter(inbox =>
    linkedInboxIds.value.includes(inbox.id)
  )
);

const fetchChannels = async id => {
  try {
    const { data } = await ContactAPI.getConversations(id);
    linkedInboxIds.value = data.payload.map(
      conversation => conversation.inbox_id
    );
  } catch (error) {
    linkedInboxIds.value = [];
  }
};

watch(() => props.contactId, fetchChannels, { immediate: true });
</script>

<template>
  <div class="flex flex-col items-start w-full gap-1">
    <span
      v-for="inbox in inboxes"
      :key="inbox.id"
      class="flex items-center min-w-0 max-w-full gap-2 text-sm text-n-slate-12"
    >
      <ChannelIcon
        :inbox="inbox"
        use-brand-icon
        class="flex-shrink-0 size-4 text-n-slate-11"
      />
      <span class="truncate">{{ inbox.name }}</span>
    </span>
  </div>
</template>
