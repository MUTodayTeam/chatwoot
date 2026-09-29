<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CasesAPI from 'dashboard/api/cases';
import CaseSeverityLabel from 'dashboard/components-next/Cases/CaseSeverityLabel.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
  // Refetches once the case of the open conversation is created
  caseId: {
    type: Number,
    default: null,
  },
});

const { t } = useI18n();
const router = useRouter();
const { run, isPending } = useAbortableRequest();

const cases = ref([]);

const fetchCases = async () => {
  try {
    const response = await run(signal =>
      CasesAPI.get({ contact_id: props.contactId }, { signal })
    );
    if (response) cases.value = response.data.payload;
  } catch (error) {
    useAlert(t('CASES.API.ERROR_MESSAGE'));
  }
};

const openCases = () => {
  router.push({
    name: 'cases_index',
    query: { contact_id: props.contactId },
  });
};

watch(() => [props.contactId, props.caseId], fetchCases, { immediate: true });
</script>

<template>
  <div class="flex flex-col gap-2 px-2 pb-2">
    <div v-if="isPending && !cases.length" class="flex justify-center py-2">
      <Spinner :size="16" />
    </div>
    <p v-else-if="!cases.length" class="m-0 text-body-main text-n-slate-11">
      {{ t('CASES.RELATED.EMPTY') }}
    </p>
    <button
      v-for="kase in cases"
      :key="kase.id"
      type="button"
      class="flex items-center w-full gap-2 px-2 py-1.5 text-start border rounded-lg border-n-weak hover:bg-n-alpha-1"
      @click="openCases"
    >
      <span class="text-label-small text-n-ruby-11 whitespace-nowrap">
        {{ kase.display }}
      </span>
      <span class="flex-1 min-w-0 truncate text-body-main text-n-slate-12">
        {{ kase.subject }}
      </span>
      <CaseSeverityLabel :severity="kase.severity" />
    </button>
  </div>
</template>
