<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import CaseCategoriesAPI from 'dashboard/api/caseCategories';
import { downloadCsvFile } from 'dashboard/helper/downloadHelper';
import {
  ALL_INQUIRY_TYPES,
  INQUIRY_TYPES,
  INQUIRY_TYPE_FILTERS,
  countByInquiryType,
  filterCategories,
} from 'dashboard/helper/caseCategoryHelper';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import ImportResultDialog from './ImportResultDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import DurationInput from 'dashboard/components-next/input/DurationInput.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import CategorySla from 'dashboard/components-next/Cases/CategorySla.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const TEMPLATE_FILE_NAME = 'case-categories-template.csv';
const EXPORT_FILE_NAME = 'case-categories.csv';
const CSV_COLUMNS = ['A', 'B', 'C', 'D'];
// Spec 15: a new row defaults to Request, as an import without column E does
const DEFAULT_INQUIRY_TYPE = 'request';

const { t } = useI18n();
const { run, isPending } = useAbortableRequest();

const categories = ref([]);
const hasLoaded = ref(false);
const inquiryType = ref(ALL_INQUIRY_TYPES);
const query = ref('');
const isAdding = ref(false);
const isImporting = ref(false);
const fileInputRef = ref(null);
const importResultRef = ref(null);
const showDeleteConfirmation = ref(false);
const categoryToDelete = ref(null);

const emptyForm = () => ({
  inquiry_type: DEFAULT_INQUIRY_TYPE,
  c1: '',
  c2: '',
  c3: '',
  sla_respond_minutes: null,
  sla_resolve_minutes: null,
});
const form = ref(emptyForm());
const respondUnit = ref(DURATION_UNITS.MINUTES);
const resolveUnit = ref(DURATION_UNITS.DAYS);

const inquiryTypeLabel = type => t(`CASE_CATEGORIES.INQUIRY_TYPES.${type}`);
const inquiryTypeOptions = computed(() =>
  INQUIRY_TYPES.map(type => ({ value: type, label: inquiryTypeLabel(type) }))
);
const tabs = computed(() => {
  const counts = countByInquiryType(categories.value);
  return INQUIRY_TYPE_FILTERS.map(type => ({
    key: type,
    label: inquiryTypeLabel(type),
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
const canAdd = computed(
  () => !isAdding.value && !!form.value.c1.trim() && !!form.value.c3.trim()
);

const tableHeaders = computed(() => [
  t('CASE_CATEGORIES.TABLE.INQUIRY_TYPE'),
  t('CASE_CATEGORIES.TABLE.C1'),
  t('CASE_CATEGORIES.TABLE.C2'),
  t('CASE_CATEGORIES.TABLE.C3'),
  t('CASE_CATEGORIES.TABLE.SLA'),
  t('CASE_CATEGORIES.TABLE.ACTION'),
]);

const fetchCategories = async () => {
  try {
    const response = await run(signal => CaseCategoriesAPI.get({}, { signal }));
    // A newer request replaced this one
    if (!response) return;
    categories.value = response.data.payload;
  } catch (error) {
    useAlert(t('CASE_CATEGORIES.FETCH_ERROR'));
  } finally {
    hasLoaded.value = true;
  }
};

const onTabChange = tab => {
  inquiryType.value = tab.key;
};

const addCategory = async () => {
  if (!canAdd.value) return;
  isAdding.value = true;
  try {
    await CaseCategoriesAPI.create({ case_category: form.value });
    form.value = emptyForm();
    useAlert(t('CASE_CATEGORIES.ADD.SUCCESS'));
    fetchCategories();
  } catch (error) {
    useAlert(error?.response?.data?.message || t('CASE_CATEGORIES.ADD.ERROR'));
  } finally {
    isAdding.value = false;
  }
};

const openDeleteConfirmation = category => {
  categoryToDelete.value = category;
  showDeleteConfirmation.value = true;
};

const closeDeleteConfirmation = () => {
  showDeleteConfirmation.value = false;
};

const deleteMessageValue = computed(() =>
  categoryToDelete.value ? ` ${categoryToDelete.value.c3}?` : ''
);

const confirmDeletion = async () => {
  const category = categoryToDelete.value;
  closeDeleteConfirmation();
  try {
    await CaseCategoriesAPI.delete(category.id);
    categories.value = categories.value.filter(item => item.id !== category.id);
    useAlert(t('CASE_CATEGORIES.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(t('CASE_CATEGORIES.DELETE.ERROR'));
  }
};

const download = async (request, fileName) => {
  try {
    const response = await request();
    downloadCsvFile(fileName, response.data);
  } catch (error) {
    useAlert(t('CASE_CATEGORIES.DOWNLOAD_ERROR'));
  }
};

const downloadTemplate = () =>
  download(() => CaseCategoriesAPI.downloadTemplate(), TEMPLATE_FILE_NAME);
const exportCategories = () =>
  download(() => CaseCategoriesAPI.export(), EXPORT_FILE_NAME);

const chooseImportFile = () => fileInputRef.value?.click();

const importFile = async event => {
  const [file] = event.target.files;
  // Picking the same file again still fires change
  event.target.value = '';
  if (!file) return;

  isImporting.value = true;
  try {
    const { data } = await CaseCategoriesAPI.import(file);
    importResultRef.value?.open(file.name, data);
    fetchCategories();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('CASE_CATEGORIES.IMPORT_ERROR'));
  } finally {
    isImporting.value = false;
  }
};

onMounted(fetchCategories);
</script>

<template>
  <SettingsLayout
    :is-loading="!hasLoaded"
    :loading-message="t('CASE_CATEGORIES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CASE_CATEGORIES.HEADER')"
        :description="t('CASE_CATEGORIES.DESCRIPTION')"
      >
        <template v-if="categories.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ t('CASE_CATEGORIES.COUNT', categories.length) }}
          </span>
        </template>
        <template #actions>
          <div class="flex flex-wrap gap-2">
            <Button
              :label="t('CASE_CATEGORIES.TEMPLATE')"
              icon="i-lucide-download"
              variant="faded"
              color="slate"
              size="sm"
              @click="downloadTemplate"
            />
            <Button
              :label="t('CASE_CATEGORIES.EXPORT')"
              icon="i-lucide-upload"
              variant="faded"
              color="slate"
              size="sm"
              @click="exportCategories"
            />
            <Button
              :label="t('CASE_CATEGORIES.IMPORT')"
              icon="i-lucide-file-up"
              size="sm"
              :is-loading="isImporting"
              @click="chooseImportFile"
            />
            <input
              ref="fileInputRef"
              type="file"
              accept=".csv,text/csv"
              class="hidden"
              @change="importFile"
            />
          </div>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-4">
          <div
            v-for="column in CSV_COLUMNS"
            :key="column"
            class="flex flex-col gap-0.5 p-3 rounded-lg bg-n-alpha-1"
          >
            <span class="text-label-small uppercase text-n-slate-11">
              {{ t('CASE_CATEGORIES.COLUMNS.TITLE', { column }) }}
            </span>
            <span class="text-heading-3 text-n-slate-12">
              {{ tableHeaders[CSV_COLUMNS.indexOf(column) + 1] }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ t(`CASE_CATEGORIES.COLUMNS.${column}`) }}
            </span>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <Input
            v-model="query"
            :placeholder="t('CASE_CATEGORIES.SEARCH_PLACEHOLDER')"
            size="sm"
            class="w-72 max-w-full"
          />
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTabIndex"
            @tab-changed="onTabChange"
          />
        </div>

        <form
          class="grid items-end grid-cols-1 gap-2 p-3 rounded-lg md:grid-cols-6 bg-n-alpha-1"
          @submit.prevent="addCategory"
        >
          <Select
            v-model="form.inquiry_type"
            :options="inquiryTypeOptions"
            :aria-label="t('CASE_CATEGORIES.TABLE.INQUIRY_TYPE')"
          />
          <Input
            v-model="form.c1"
            :placeholder="t('CASE_CATEGORIES.TABLE.C1')"
            size="sm"
          />
          <Input
            v-model="form.c2"
            :placeholder="t('CASE_CATEGORIES.TABLE.C2')"
            size="sm"
          />
          <Input
            v-model="form.c3"
            :placeholder="t('CASE_CATEGORIES.TABLE.C3')"
            size="sm"
          />
          <div class="flex flex-col gap-2 md:col-span-2">
            <div class="flex items-center gap-2">
              <span class="w-28 shrink-0 text-label-small text-n-slate-11">
                {{ t('CASE_CATEGORIES.SLA.RESPOND') }}
              </span>
              <DurationInput
                v-model:model-value="form.sla_respond_minutes"
                v-model:unit="respondUnit"
                :min="1"
              />
            </div>
            <div class="flex items-center gap-2">
              <span class="w-28 shrink-0 text-label-small text-n-slate-11">
                {{ t('CASE_CATEGORIES.SLA.RESOLVE') }}
              </span>
              <DurationInput
                v-model:model-value="form.sla_resolve_minutes"
                v-model:unit="resolveUnit"
                :min="1"
              />
            </div>
          </div>
          <Button
            :label="t('CASE_CATEGORIES.ADD.BUTTON')"
            icon="i-lucide-plus"
            size="sm"
            type="submit"
            class="md:col-start-6 justify-self-end"
            :is-loading="isAdding"
            :disabled="!canAdd"
          />
        </form>

        <BaseTable
          :headers="tableHeaders"
          :items="visibleCategories"
          :loading="isPending"
          :no-data-message="t('CASE_CATEGORIES.EMPTY')"
        >
          <template #row="{ items }">
            <BaseTableRow
              v-for="category in items"
              :key="category.id"
              :item="category"
            >
              <BaseTableCell>
                <Label
                  :label="inquiryTypeLabel(category.inquiry_type)"
                  compact
                />
              </BaseTableCell>
              <BaseTableCell>
                <Label :label="category.c1" color="blue" compact />
              </BaseTableCell>
              <BaseTableCell>{{ category.c2 }}</BaseTableCell>
              <BaseTableCell>
                <span class="text-heading-3 text-n-slate-12">
                  {{ category.c3 }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <CategorySla
                  :respond-minutes="category.sla_respond_minutes"
                  :resolve-minutes="category.sla_resolve_minutes"
                />
              </BaseTableCell>
              <BaseTableCell align="end">
                <Button
                  v-tooltip.top="t('CASE_CATEGORIES.DELETE.BUTTON')"
                  icon="i-woot-bin"
                  slate
                  sm
                  class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                  @click="openDeleteConfirmation(category)"
                />
              </BaseTableCell>
            </BaseTableRow>
          </template>
        </BaseTable>
      </div>
    </template>

    <ImportResultDialog ref="importResultRef" />

    <woot-delete-modal
      v-model:show="showDeleteConfirmation"
      :on-close="closeDeleteConfirmation"
      :on-confirm="confirmDeletion"
      :title="t('CASE_CATEGORIES.DELETE.TITLE')"
      :message="t('CASE_CATEGORIES.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="t('CASE_CATEGORIES.DELETE.YES')"
      :reject-text="t('CASE_CATEGORIES.DELETE.NO')"
    />
  </SettingsLayout>
</template>
