<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { categoryPath } from 'dashboard/helper/caseCategoryHelper';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import CategorySla from 'dashboard/components-next/Cases/CategorySla.vue';

// What an import added, skipped and could not read (spec 15)
const { t } = useI18n();

const dialogRef = ref(null);
const fileName = ref('');
const result = ref({ added: [], skipped: 0, invalid: [] });

const open = (name, importResult) => {
  fileName.value = name;
  result.value = importResult;
  dialogRef.value?.open();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="t('CASE_CATEGORIES.IMPORT_RESULT.TITLE', { fileName })"
    :show-cancel-button="false"
    :confirm-button-label="t('CASE_CATEGORIES.IMPORT_RESULT.CLOSE')"
    @confirm="dialogRef.close()"
  >
    <div class="grid grid-cols-3 gap-3">
      <div class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-1">
        <span class="text-label-small uppercase text-n-slate-11">
          {{ t('CASE_CATEGORIES.IMPORT_RESULT.ADDED') }}
        </span>
        <span class="text-heading-1 text-n-slate-12">
          {{ result.added.length }}
        </span>
      </div>
      <div class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-1">
        <span class="text-label-small uppercase text-n-slate-11">
          {{ t('CASE_CATEGORIES.IMPORT_RESULT.SKIPPED') }}
        </span>
        <span class="text-heading-1 text-n-slate-11">
          {{ result.skipped }}
        </span>
      </div>
      <div class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-1">
        <span class="text-label-small uppercase text-n-slate-11">
          {{ t('CASE_CATEGORIES.IMPORT_RESULT.INVALID') }}
        </span>
        <span class="text-heading-1 text-n-ruby-11">
          {{ result.invalid.length }}
        </span>
      </div>
    </div>
    <ul
      v-if="result.added.length || result.invalid.length"
      class="flex flex-col m-0 overflow-y-auto list-none divide-y max-h-56 divide-n-weak"
    >
      <li
        v-for="category in result.added"
        :key="`added-${category.id}`"
        class="flex items-center gap-3 py-2 text-body-main text-n-slate-12"
      >
        <span class="min-w-0 truncate">{{ categoryPath(category) }}</span>
        <CategorySla
          :respond-minutes="category.sla_respond_minutes"
          :resolve-minutes="category.sla_resolve_minutes"
          class="text-label-small text-n-slate-11 ms-auto"
        />
      </li>
      <li
        v-for="row in result.invalid"
        :key="`invalid-${row.line}`"
        class="flex flex-col gap-0.5 py-2 text-body-main text-n-ruby-11"
      >
        <span>
          {{
            t('CASE_CATEGORIES.IMPORT_RESULT.INVALID_ROW', {
              line: row.line,
              reason: t(`CASE_CATEGORIES.IMPORT_RESULT.REASONS.${row.reason}`),
            })
          }}
        </span>
        <span class="text-label-small text-n-slate-11 truncate">
          {{ row.values.join(' | ') }}
        </span>
      </li>
    </ul>
  </Dialog>
</template>
