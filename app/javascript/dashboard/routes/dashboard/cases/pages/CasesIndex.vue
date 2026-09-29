<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { useOpenConversationThread } from 'dashboard/composables/useOpenConversationThread';
import CasesAPI from 'dashboard/api/cases';
import {
  buildCaseTabs,
  caseTabParams,
  CASE_TABS,
  CASE_FINISHED_STATUSES,
} from 'dashboard/helper/caseHelper';
import { categoryPath } from 'dashboard/helper/caseCategoryHelper';
import { dynamicTime } from 'shared/helpers/timeHelper';

import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import Label from 'dashboard/components-next/label/Label.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import CaseSeverityLabel from 'dashboard/components-next/Cases/CaseSeverityLabel.vue';
import CaseStatusLabel from 'dashboard/components-next/Cases/CaseStatusLabel.vue';
import AutoTransitionCountdown from 'dashboard/components-next/Conversation/AutoTransitionCountdown.vue';
import ContactProjectFilter from 'dashboard/components-next/Contacts/ContactProjectFilter.vue';
import ChannelName from 'dashboard/routes/dashboard/settings/inbox/components/ChannelName.vue';

// Matches CaseFinder::RESULTS_PER_PAGE
const RESULTS_PER_PAGE = 25;

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();
const { run, isPending } = useAbortableRequest();
const openConversationThread = useOpenConversationThread();

const teams = useMapGetter('teams/getTeams');
const inboxGetter = useMapGetter('inboxes/getInbox');
const liveChatRules = useMapGetter('liveChatRules/getLiveChatRules');

const cases = ref([]);
const meta = ref({ count: 0, open_count: 0 });
const hasLoaded = ref(false);

// Seeded from the URL so a shared link, or the contact panel, opens the same view
const activeTabKey = ref(route.query.tab || CASE_TABS.ALL);
const contactId = ref(route.query.contact_id || null);
// The header counts follow it: CaseFinder scopes count and open_count by project_id
const projectId = ref(Number(route.query.project_id) || null);
const currentPage = ref(Number(route.query.page) || 1);

const tabLabel = tab => {
  if (tab.label) return tab.label;
  return tab.key === CASE_TABS.MINE
    ? t('CASES.TABS.MINE')
    : t('CASES.TABS.ALL');
};
const tabs = computed(() =>
  buildCaseTabs(teams.value).map(tab => ({ ...tab, label: tabLabel(tab) }))
);
const activeTab = computed(
  () => tabs.value.find(tab => tab.key === activeTabKey.value) || tabs.value[0]
);
const activeTabIndex = computed(() => tabs.value.indexOf(activeTab.value));
const isMyCases = computed(() => activeTab.value.key === CASE_TABS.MINE);

const headers = computed(() => [
  t('CASES.TABLE.NUMBER'),
  t('CASES.TABLE.PROJECT'),
  t('CASES.TABLE.CONTACT'),
  t('CASES.TABLE.SUBJECT'),
  t('CASES.TABLE.TOPIC'),
  t('CASES.TABLE.SEVERITY'),
  t('CASES.TABLE.STATUS'),
  t('CASES.TABLE.TEAM'),
  t('CASES.TABLE.OWNER'),
  t('CASES.TABLE.THREAD'),
  t('CASES.TABLE.TIME'),
]);

const summary = computed(
  () =>
    `${t('CASES.COUNT', meta.value.count)} · ${t('CASES.OPEN_COUNT', { n: meta.value.open_count })}`
);

const inboxMedium = inboxId => inboxGetter.value(inboxId)?.medium;

// The countdown reads a case as the conversation it mirrors.
const countdownConversation = kase => ({
  inbox_id: kase.conversation.inbox_id,
  status: kase.status,
  status_changed_at: kase.conversation.status_changed_at,
  meta: { assignee_type: kase.conversation.assignee_type },
});

// Picked when the case was solved: a solved case without one is "Other", an open one has none yet
const caseTopic = kase => {
  if (kase.category) return kase.category.c3;
  return CASE_FINISHED_STATUSES.includes(kase.status)
    ? t('CASES.TOPIC_OTHER')
    : '';
};

const syncFiltersToUrl = () => {
  router.replace({
    query: {
      ...(activeTabKey.value !== CASE_TABS.ALL && { tab: activeTabKey.value }),
      ...(contactId.value && { contact_id: contactId.value }),
      ...(projectId.value && { project_id: projectId.value }),
      ...(currentPage.value > 1 && { page: currentPage.value }),
    },
  });
};

const fetchCases = async () => {
  syncFiltersToUrl();
  try {
    const response = await run(signal =>
      CasesAPI.get(
        {
          ...caseTabParams(activeTab.value),
          ...(contactId.value && { contact_id: contactId.value }),
          ...(projectId.value && { project_id: projectId.value }),
          page: currentPage.value,
        },
        { signal }
      )
    );
    // A newer request replaced this one
    if (!response) return;
    cases.value = response.data.payload;
    meta.value = response.data.meta;
  } catch (error) {
    useAlert(t('CASES.API.ERROR_MESSAGE'));
  } finally {
    hasLoaded.value = true;
  }
};

const onTabChange = tab => {
  activeTabKey.value = tab.key;
};

const clearContactFilter = () => {
  contactId.value = null;
};

watch([activeTabKey, contactId, projectId], () => {
  currentPage.value = 1;
  fetchCases();
});

const onPageChange = page => {
  currentPage.value = page;
  fetchCases();
};

const openThread = kase =>
  openConversationThread({ id: kase.conversation.id, status: kase.status });

onMounted(() => {
  store.dispatch('teams/get');
  store.dispatch('inboxes/get');
  if (!liveChatRules.value.length) store.dispatch('liveChatRules/get');
  fetchCases();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="shrink-0 px-6 pt-6">
      <p class="m-0 text-label-small uppercase text-n-ruby-11">
        {{ summary }}
      </p>
      <h1 class="m-0 text-heading-1 text-n-slate-12">
        {{ t('CASES.HEADER') }}
      </h1>
      <p class="m-0 mt-1 text-body-main text-n-slate-11">
        {{ t('CASES.DESCRIPTION') }}
      </p>
      <div class="flex flex-wrap items-center gap-3 mt-5">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChange"
        />
        <ContactProjectFilter v-model="projectId" />
        <div v-if="contactId" class="flex items-center gap-2">
          <span class="text-body-main text-n-slate-11">
            {{ t('CASES.CONTACT_FILTER') }}
          </span>
          <Button
            :label="t('CASES.CLEAR_FILTER')"
            variant="link"
            size="sm"
            @click="clearContactFilter"
          />
        </div>
      </div>
      <p v-if="isMyCases" class="m-0 mt-2 text-label-small text-n-slate-11">
        {{ t('CASES.MINE_HINT') }}
      </p>
    </header>
    <main class="flex-1 px-6 mt-4 overflow-auto">
      <div
        v-if="isPending && !cases.length"
        class="flex items-center justify-center py-16"
      >
        <Spinner :size="24" />
      </div>
      <BaseTable
        v-else
        :headers="headers"
        :items="cases"
        :loading="isPending || !hasLoaded"
        :no-data-message="t('CASES.EMPTY_STATE')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="kase in items" :key="kase.id" :item="kase">
            <BaseTableCell>
              <span class="text-heading-3 text-n-ruby-11 whitespace-nowrap">
                {{ kase.display }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <div class="flex flex-col items-start gap-1">
                <Label
                  v-if="kase.project"
                  :label="{
                    title: kase.project.name,
                    color: kase.project.color,
                  }"
                  compact
                />
                <span v-else class="text-n-slate-11">
                  {{ t('CASES.NO_PROJECT') }}
                </span>
                <ChannelName
                  :channel-type="kase.conversation.channel"
                  :medium="inboxMedium(kase.conversation.inbox_id)"
                  class="text-label-small text-n-slate-11"
                />
              </div>
            </BaseTableCell>
            <BaseTableCell>
              <span class="text-n-slate-12">{{ kase.contact.name }}</span>
            </BaseTableCell>
            <BaseTableCell>
              <span class="block max-w-60 truncate text-n-slate-12">
                {{ kase.subject }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <span
                v-tooltip.top="kase.category ? categoryPath(kase.category) : ''"
                class="block max-w-48 truncate text-n-slate-12"
              >
                {{ caseTopic(kase) }}
              </span>
            </BaseTableCell>
            <BaseTableCell>
              <CaseSeverityLabel :severity="kase.severity" />
            </BaseTableCell>
            <BaseTableCell>
              <div class="flex flex-col items-start gap-1">
                <CaseStatusLabel :status="kase.status" />
                <span
                  v-if="kase.reopened_count"
                  class="text-label-small text-n-ruby-11 whitespace-nowrap"
                >
                  {{ t('CASES.REOPENED', { count: kase.reopened_count }) }}
                </span>
                <AutoTransitionCountdown :chat="countdownConversation(kase)" />
              </div>
            </BaseTableCell>
            <BaseTableCell>
              {{ kase.team?.name || t('CASES.NO_TEAM') }}
            </BaseTableCell>
            <BaseTableCell>
              <div v-if="kase.owner" class="flex items-center gap-2">
                <Avatar
                  :name="kase.owner.name"
                  :src="kase.owner.thumbnail"
                  :size="20"
                  rounded-full
                />
                <span class="text-n-slate-12 whitespace-nowrap">
                  {{ kase.owner.name }}
                </span>
              </div>
              <span v-else>{{ t('CASES.UNASSIGNED') }}</span>
            </BaseTableCell>
            <BaseTableCell>
              <Button
                :label="t('CASES.OPEN_THREAD')"
                variant="link"
                size="sm"
                @click="openThread(kase)"
              />
            </BaseTableCell>
            <BaseTableCell>
              <span class="whitespace-nowrap">
                {{ dynamicTime(kase.created_at) }}
              </span>
            </BaseTableCell>
          </BaseTableRow>
        </template>
      </BaseTable>
    </main>
    <footer v-if="cases.length" class="sticky bottom-0 shrink-0">
      <PaginationFooter
        :current-page="currentPage"
        :total-items="meta.count"
        :items-per-page="RESULTS_PER_PAGE"
        @update:current-page="onPageChange"
      />
    </footer>
  </section>
</template>
