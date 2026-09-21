<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import ProjectForm from './ProjectForm.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const store = useStore();
const { t } = useI18n();

const showFormPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedProject = ref(null);

const records = useMapGetter('projects/getProjects');
const uiFlags = useMapGetter('projects/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');

const inboxNamesFor = project => {
  const ids = project.inboxIds ?? [];
  const names = inboxes.value
    .filter(inbox => ids.includes(inbox.id))
    .map(inbox => inbox.name);
  return names.length ? names.join(', ') : t('PROJECT_MGMT.LIST.NO_INBOXES');
};

const openAddPopup = () => {
  selectedProject.value = null;
  showFormPopup.value = true;
};

const openEditPopup = project => {
  selectedProject.value = project;
  showFormPopup.value = true;
};

const hideFormPopup = () => {
  showFormPopup.value = false;
  selectedProject.value = null;
};

const openDeletePopup = project => {
  selectedProject.value = project;
  showDeleteConfirmationPopup.value = true;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteMessage = computed(() => ` ${selectedProject.value?.name}?`);

const confirmDeletion = async () => {
  const project = selectedProject.value;
  closeDeletePopup();
  try {
    await store.dispatch('projects/delete', project.id);
    useAlert(t('PROJECT_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error?.message || t('PROJECT_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};

const tableHeaders = computed(() => [
  t('PROJECT_MGMT.LIST.TABLE_HEADER.NAME'),
  t('PROJECT_MGMT.LIST.TABLE_HEADER.DESCRIPTION'),
  t('PROJECT_MGMT.LIST.TABLE_HEADER.INBOXES'),
  t('PROJECT_MGMT.LIST.TABLE_HEADER.ACTION'),
]);

onBeforeMount(() => {
  store.dispatch('projects/get');
  store.dispatch('inboxes/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('PROJECT_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('PROJECT_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PROJECT_MGMT.HEADER')"
        :description="$t('PROJECT_MGMT.DESCRIPTION')"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('PROJECT_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('PROJECT_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="records"
        :no-data-message="$t('PROJECT_MGMT.LIST.404')"
      >
        <template #row="{ items }">
          <BaseTableRow
            v-for="project in items"
            :key="project.id"
            :item="project"
          >
            <template #default>
              <BaseTableCell>
                <div class="flex items-center gap-2">
                  <span
                    class="flex-shrink-0 w-3 h-3 border border-solid rounded-sm border-n-weak"
                    :style="{ backgroundColor: project.color }"
                  />
                  <span class="text-body-main text-n-slate-12">
                    {{ project.name }}
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ project.description }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{ inboxNamesFor(project) }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex justify-end flex-shrink-0 gap-3">
                  <Button
                    v-tooltip.top="$t('PROJECT_MGMT.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(project)"
                  />
                  <Button
                    v-tooltip.top="$t('PROJECT_MGMT.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(project)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showFormPopup" :on-close="hideFormPopup">
      <ProjectForm :project="selectedProject" @close="hideFormPopup" />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('PROJECT_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('PROJECT_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('PROJECT_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="$t('PROJECT_MGMT.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
