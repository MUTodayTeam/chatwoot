<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { contactProfile } from 'dashboard/helper/contact360Helper';

// The conversation panel's contact block: Type and Partner ID, and the way to Contact 360
const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const profileLine = computed(() => {
  const { type, partnerId } = contactProfile(props.contact);
  return [type, partnerId && t('CONTACT_360.PARTNER_ID', { id: partnerId })]
    .filter(Boolean)
    .join(' · ');
});
</script>

<template>
  <div class="flex flex-col items-start w-full gap-1">
    <p v-if="profileLine" class="m-0 text-body-main text-n-slate-11">
      {{ profileLine }}
    </p>
    <router-link
      v-if="contact.id"
      :to="{ name: 'contacts_edit', params: { contactId: contact.id } }"
      class="text-label-small text-n-blue-11 hover:underline"
    >
      {{ t('CONTACT_360.OPEN_LINK') }}
    </router-link>
  </div>
</template>
