<script setup>
import { computed, ref, watch } from 'vue';
import ContactAPI from 'dashboard/api/contacts';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const contactInboxes = ref([]);

// One row per inbox the contact has written to, however many times it did
const inboxes = computed(() => [
  ...new Map(contactInboxes.value.map(ci => [ci.inbox.id, ci.inbox])).values(),
]);

const fetchChannels = async id => {
  try {
    const { data } = await ContactAPI.getChannels(id);
    contactInboxes.value = data.contact_inboxes || [];
  } catch (error) {
    contactInboxes.value = [];
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
