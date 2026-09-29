<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaseCategoriesAPI from 'dashboard/api/caseCategories';
import {
  ALL_INQUIRY_TYPES,
  INQUIRY_TYPE_FILTERS,
  categoryPath,
  countByInquiryType,
  filterCategories,
} from 'dashboard/helper/caseCategoryHelper';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';
import CategorySla from './CategorySla.vue';

// Select Category (spec 7.3): the topic an agent files a case under when solving it
const props = defineProps({
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['solve']);

const { t } = useI18n();
const router = useRouter();
const { isAdmin } = useAdmin();
const { run, isPending } = useAbortableRequest();
const accountId = useMapGetter('getCurrentAccountId');

const dialogRef = ref(null);
const categories = ref([]);
const hasLoaded = ref(false);
const inquiryType = ref(ALL_INQUIRY_TYPES);
const query = ref('');
const selectedId = ref(null);
const summary = ref('');
const sendSurvey = ref(true);

const tabs = computed(() => {
  const counts = countByInquiryType(categories.value);
  return INQUIRY_TYPE_FILTERS.map(type => ({
    key: type,
    label: t(`CASE_CATEGORIES.INQUIRY_TYPES.${type}`),
    count: counts[type],
  }));
});
const activeTabIndex = computed(() =>
  INQUIRY_TYPE_FILTERS.indexOf(inquiryType.value)
);

const visibleCategories = computed(() =>
  filterCategories(categories.value, {
    inquiryType: inquiryType.value,
    query: query.value,
  })
);
const selectedCategory = computed(() =>
  categories.value.find(category => category.id === selectedId.value)
);
// A fresh account has none yet, and agents must still be able to solve: that is "Other"
const hasNoCategories = computed(
  () => hasLoaded.value && !categories.value.length
);
const canSolve = computed(
  () => !props.isLoading && (!!selectedCategory.value || hasNoCategories.value)
);
const submitLabel = computed(() => {
  if (selectedCategory.value) {
    return t('CASE_CATEGORIES.SOLVE.SUBMIT', {
      name: selectedCategory.value.c3,
    });
  }
  if (hasNoCategories.value) {
    return t('CASE_CATEGORIES.SOLVE.SUBMIT', {
      name: t('CASE_CATEGORIES.SOLVE.OTHER'),
    });
  }
  return t('CASE_CATEGORIES.SOLVE.CHOOSE_FIRST');
});

const tableHeaders = computed(() => [
  t('CASE_CATEGORIES.TABLE.C1'),
  t('CASE_CATEGORIES.TABLE.C2'),
  t('CASE_CATEGORIES.TABLE.C3'),
  t('CASE_CATEGORIES.TABLE.SLA'),
]);

const fetchCategories = async () => {
  try {
    const response = await run(signal => CaseCategoriesAPI.get({}, { signal }));
    // A newer request replaced this one
    if (!response) return;
    categories.value = response.data.payload;
    hasLoaded.value = true;
  } catch (error) {
    useAlert(t('CASE_CATEGORIES.FETCH_ERROR'));
  }
};

// currentCategoryId: the case's category from an earlier solve, preselected
const open = (currentCategoryId = null) => {
  inquiryType.value = ALL_INQUIRY_TYPES;
  query.value = '';
  selectedId.value = currentCategoryId;
  summary.value = '';
  sendSurvey.value = true;
  hasLoaded.value = false;
  fetchCategories();
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

defineExpose({ open, close });

const onTabChange = tab => {
  inquiryType.value = tab.key;
};

const selectCategory = category => {
  selectedId.value = category.id;
};

const clearCategory = () => {
  selectedId.value = null;
};

const solve = () => {
  if (!canSolve.value) return;
  emit('solve', {
    caseCategoryId: selectedCategory.value?.id ?? null,
    summary: summary.value.trim(),
    sendSurvey: sendSurvey.value,
  });
};

const manageCategories = () => {
  close();
  router.push({
    name: 'case_categories_index',
    params: { accountId: accountId.value },
  });
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="4xl"
    :show-cancel-button="false"
    :show-confirm-button="false"
  >
    <div class="flex flex-col gap-4 min-w-0">
      <div class="flex items-center gap-3">
        <h3 class="m-0 text-heading-2 text-n-slate-12">
          {{ t('CASE_CATEGORIES.SOLVE.TITLE') }}
        </h3>
        <Button
          v-if="isAdmin"
          :label="t('CASE_CATEGORIES.SOLVE.MANAGE')"
          variant="faded"
          color="slate"
          size="sm"
          type="button"
          class="ms-auto"
          @click="manageCategories"
        />
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <span class="text-label-small text-n-slate-11">
          {{ t('CASE_CATEGORIES.SOLVE.INQUIRY_TYPE') }}
        </span>
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTabIndex"
          @tab-changed="onTabChange"
        />
      </div>

      <div
        class="flex flex-wrap items-center gap-3 px-3 py-2 rounded-lg bg-n-alpha-1"
      >
        <span class="text-body-main text-n-slate-11">
          {{ t('CASE_CATEGORIES.SOLVE.CURRENT') }}
        </span>
        <template v-if="selectedCategory">
          <span class="text-heading-3 text-n-slate-12">
            {{ categoryPath(selectedCategory) }}
          </span>
          <Label
            :label="
              t(
                `CASE_CATEGORIES.INQUIRY_TYPES.${selectedCategory.inquiry_type}`
              )
            "
            compact
          />
        </template>
        <span v-else class="text-body-main text-n-slate-11">
          {{
            hasNoCategories
              ? t('CASE_CATEGORIES.SOLVE.NO_CATEGORIES')
              : t('CASE_CATEGORIES.SOLVE.NONE_SELECTED')
          }}
        </span>
        <Button
          :label="t('CASE_CATEGORIES.SOLVE.CLEAR')"
          variant="link"
          color="slate"
          size="sm"
          type="button"
          class="ms-auto"
          :disabled="!selectedCategory"
          @click="clearCategory"
        />
      </div>

      <Input
        v-model="query"
        :placeholder="t('CASE_CATEGORIES.SOLVE.SEARCH_PLACEHOLDER')"
        autofocus
      />

      <div class="overflow-y-auto max-h-[45vh] min-h-40">
        <BaseTable
          :headers="tableHeaders"
          :items="visibleCategories"
          :loading="isPending || !hasLoaded"
          :no-data-message="t('CASE_CATEGORIES.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="category in items"
              :key="category.id"
              :item="category"
              class="cursor-pointer hover:bg-n-alpha-1"
              :class="{ '!bg-n-brand/10': category.id === selectedId }"
              @click="selectCategory(category)"
            >
              <BaseTableCell>
                <Label :label="category.c1" color="blue" compact />
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-n-slate-11">{{ category.c2 }}</span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-heading-3 text-n-slate-12">
                  {{ category.c3 }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <CategorySla
                  :respond-minutes="category.sla_respond_minutes"
                  :resolve-minutes="category.sla_resolve_minutes"
                  class="text-label-small text-n-slate-11"
                />
              </BaseTableCell>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>

      <div
        class="flex items-center justify-between text-label-small text-n-slate-11"
      >
        <span>
          {{ t('CASE_CATEGORIES.SOLVE.COUNT', visibleCategories.length) }}
        </span>
        <span>{{ t('CASE_CATEGORIES.SOLVE.HINT') }}</span>
      </div>
    </div>

    <template #footer>
      <div class="flex flex-col gap-3 pt-4 border-t border-n-weak">
        <Input
          v-model="summary"
          :placeholder="t('CASE_CATEGORIES.SOLVE.SUMMARY_PLACEHOLDER')"
        />
        <div class="flex flex-wrap items-center gap-3">
          <label class="flex items-center gap-2 text-body-main text-n-slate-12">
            <Checkbox v-model="sendSurvey" />
            {{ t('CASE_CATEGORIES.SOLVE.SEND_SURVEY') }}
          </label>
          <div class="flex items-center gap-2 ms-auto">
            <Button
              :label="t('CASE_CATEGORIES.SOLVE.CANCEL')"
              variant="faded"
              color="slate"
              type="button"
              @click="close"
            />
            <Button
              :label="submitLabel"
              type="button"
              :is-loading="isLoading"
              :disabled="!canSolve"
              @click="solve"
            />
          </div>
        </div>
      </div>
    </template>
  </Dialog>
</template>
