<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useOpenConversationThread } from 'dashboard/composables/useOpenConversationThread';
import ContactAPI from 'dashboard/api/contacts';
import CasesAPI from 'dashboard/api/cases';
import {
  contactProfile,
  formatShortDate,
  historyHandler,
  HANDLER_TYPES,
} from 'dashboard/helper/contact360Helper';

import Button from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CaseSeverityLabel from 'dashboard/components-next/Cases/CaseSeverityLabel.vue';
import CaseStatusLabel from 'dashboard/components-next/Cases/CaseStatusLabel.vue';
import ChannelName from 'dashboard/routes/dashboard/settings/inbox/components/ChannelName.vue';

const props = defineProps({
  contact: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const router = useRouter();
const openConversationThread = useOpenConversationThread();
const { run: runOverview, isPending: isFetchingOverview } =
  useAbortableRequest();
const { run: runCases, isPending: isFetchingCases } = useAbortableRequest();

const overview = ref(null);
const cases = ref([]);
const casesCount = ref(0);

const profile = computed(() => contactProfile(props.contact));
const latestConversation = computed(
  () => overview.value?.latest_conversation || null
);

// "Type · ID · First contact dd/mm/yy · n conversations", leaving out what is unknown
const profileLine = computed(() => {
  const { type, partnerId } = profile.value;
  const parts = [
    type,
    partnerId && t('CONTACT_360.PARTNER_ID', { id: partnerId }),
  ];
  if (overview.value) {
    const firstContact = formatShortDate(overview.value.first_contact_at);
    if (firstContact) {
      parts.push(t('CONTACT_360.FIRST_CONTACT', { date: firstContact }));
    }
    parts.push(
      t('CONTACT_360.CONVERSATIONS', overview.value.conversations_count)
    );
  }
  return parts.filter(Boolean).join(' · ');
});

const handlerLabel = entry => {
  const handler = historyHandler(entry);
  if (handler.type === HANDLER_TYPES.AGENT) return handler.name;
  if (handler.type === HANDLER_TYPES.BOT) return t('CONTACT_360.HISTORY.BOT');
  if (handler.type === HANDLER_TYPES.MISSED)
    return t('CONTACT_360.HISTORY.MISSED');
  return t('CONTACT_360.HISTORY.UNASSIGNED');
};

const fetchOverview = async () => {
  try {
    const response = await runOverview(signal =>
      ContactAPI.getOverview(props.contact.id, { signal })
    );
    if (response) overview.value = response.data;
  } catch (error) {
    useAlert(t('CONTACT_360.API.ERROR_MESSAGE'));
  }
};

const fetchCases = async () => {
  try {
    const response = await runCases(signal =>
      CasesAPI.get({ contact_id: props.contact.id }, { signal })
    );
    if (response) {
      cases.value = response.data.payload;
      casesCount.value = response.data.meta.count;
    }
  } catch (error) {
    useAlert(t('CASES.API.ERROR_MESSAGE'));
  }
};

const openLatestConversation = () => {
  if (latestConversation.value) {
    openConversationThread(latestConversation.value);
  }
};

const openCases = () => {
  router.push({
    name: 'cases_index',
    query: { contact_id: props.contact.id },
  });
};

watch(
  () => props.contact.id,
  () => {
    overview.value = null;
    cases.value = [];
    casesCount.value = 0;
    fetchOverview();
    fetchCases();
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col w-full gap-6">
    <div class="flex flex-wrap items-center justify-between w-full gap-3">
      <p class="m-0 text-body-main text-n-slate-11">{{ profileLine }}</p>
      <div class="flex items-center gap-2">
        <Button
          :label="t('CONTACT_360.OPEN_CHAT')"
          size="sm"
          :disabled="!latestConversation"
          @click="openLatestConversation"
        />
        <Button
          v-tooltip.top="t('CONTACT_360.CREATE_CASE_HINT')"
          :label="t('CONTACT_360.CREATE_CASE')"
          size="sm"
          color="slate"
          variant="faded"
          :disabled="!latestConversation"
          @click="openLatestConversation"
        />
      </div>
    </div>
    <div class="grid w-full gap-6 md:grid-cols-2">
      <section class="flex flex-col min-w-0 gap-2">
        <h4 class="m-0 text-heading-3 text-n-slate-12">
          {{ t('CONTACT_360.HISTORY.TITLE') }}
        </h4>
        <div
          v-if="isFetchingOverview && !overview"
          class="flex justify-center py-2"
        >
          <Spinner :size="16" />
        </div>
        <p
          v-else-if="!overview?.history.length"
          class="m-0 text-body-main text-n-slate-11"
        >
          {{ t('CONTACT_360.HISTORY.EMPTY') }}
        </p>
        <button
          v-for="entry in overview?.history"
          :key="entry.id"
          type="button"
          class="flex flex-col w-full gap-1 px-3 py-2 border rounded-lg text-start border-n-weak hover:bg-n-alpha-1"
          @click="openConversationThread(entry)"
        >
          <span class="flex items-center w-full min-w-0 gap-2">
            <span
              class="flex-1 min-w-0 truncate text-body-main text-n-slate-12"
            >
              {{ entry.topic || t('CONTACT_360.HISTORY.NO_TOPIC') }}
            </span>
            <span class="text-label-small text-n-slate-11 whitespace-nowrap">
              {{ formatShortDate(entry.created_at) }}
            </span>
          </span>
          <span
            class="flex flex-wrap items-center gap-1 text-label-small text-n-slate-11"
          >
            <Label
              v-if="entry.project"
              :label="{ title: entry.project.name, color: entry.project.color }"
              compact
            />
            <span v-else>{{ t('CONTACT_360.HISTORY.NO_PROJECT') }}</span>
            <span class="rounded-full size-1 bg-n-slate-8" />
            <ChannelName :channel-type="entry.channel" />
            <span class="rounded-full size-1 bg-n-slate-8" />
            <span>{{ handlerLabel(entry) }}</span>
            <CaseStatusLabel :status="entry.status" class="ms-auto" />
          </span>
        </button>
      </section>
      <section class="flex flex-col min-w-0 gap-2">
        <h4 class="m-0 text-heading-3 text-n-slate-12">
          {{ t('CONTACT_360.CASES.TITLE', { n: casesCount }) }}
        </h4>
        <div
          v-if="isFetchingCases && !cases.length"
          class="flex justify-center py-2"
        >
          <Spinner :size="16" />
        </div>
        <p v-else-if="!cases.length" class="m-0 text-body-main text-n-slate-11">
          {{ t('CONTACT_360.CASES.EMPTY') }}
        </p>
        <button
          v-for="kase in cases"
          :key="kase.id"
          type="button"
          class="flex items-center w-full gap-2 px-3 py-2 border rounded-lg text-start border-n-weak hover:bg-n-alpha-1"
          @click="openCases"
        >
          <span class="text-label-small text-n-ruby-11 whitespace-nowrap">
            {{ kase.display }}
          </span>
          <span class="flex-1 min-w-0 truncate text-body-main text-n-slate-12">
            {{ kase.subject }}
          </span>
          <CaseSeverityLabel :severity="kase.severity" />
          <CaseStatusLabel :status="kase.status" />
        </button>
      </section>
    </div>
  </div>
</template>
