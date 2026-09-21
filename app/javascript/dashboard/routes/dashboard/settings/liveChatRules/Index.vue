<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import LiveChatRuleForm from './LiveChatRuleForm.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

// Matches the column defaults on live_chat_rules, used for the placeholder row
// shown before an account has saved any rules of its own.
const DEFAULT_REPLY_TIMEOUT_MINUTES = 60;
const DEFAULT_EXTENSION_MINUTES = 60;

const store = useStore();
const { t } = useI18n();

const showFormPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const selectedRule = ref(null);

const records = useMapGetter('liveChatRules/getLiveChatRules');
const uiFlags = useMapGetter('liveChatRules/getUIFlags');
const projects = useMapGetter('projects/getProjects');

const accountDefault = computed(() => {
  const saved = records.value.find(rule => !rule.projectId);
  if (saved) return saved;
  // Nothing saved yet: show what the backend would fall back to, so the page
  // never implies the countdown is unconfigured.
  return {
    id: null,
    projectId: null,
    replyTimeoutMinutes: DEFAULT_REPLY_TIMEOUT_MINUTES,
    extensionMinutes: DEFAULT_EXTENSION_MINUTES,
  };
});

const overrides = computed(() => records.value.filter(rule => rule.projectId));

const rows = computed(() => [accountDefault.value, ...overrides.value]);

const scopeNameFor = rule => {
  if (!rule.projectId) return t('LIVE_CHAT_RULES.SCOPE.ACCOUNT');
  const project = projects.value.find(p => p.id === rule.projectId);
  return project?.name ?? t('LIVE_CHAT_RULES.SCOPE.UNKNOWN_PROJECT');
};

const canAddOverride = computed(
  () => overrides.value.length < projects.value.length
);

const openAddPopup = () => {
  selectedRule.value = { projectId: null };
  showFormPopup.value = true;
};

const openEditPopup = rule => {
  selectedRule.value = rule;
  showFormPopup.value = true;
};

const hideFormPopup = () => {
  showFormPopup.value = false;
  selectedRule.value = null;
};

const openDeletePopup = rule => {
  selectedRule.value = rule;
  showDeleteConfirmationPopup.value = true;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteMessage = computed(
  () => ` ${scopeNameFor(selectedRule.value ?? {})}?`
);

const confirmDeletion = async () => {
  const rule = selectedRule.value;
  closeDeletePopup();
  try {
    await store.dispatch('liveChatRules/delete', rule.id);
    useAlert(t('LIVE_CHAT_RULES.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error?.message || t('LIVE_CHAT_RULES.DELETE.API.ERROR_MESSAGE'));
  }
};

const tableHeaders = computed(() => [
  t('LIVE_CHAT_RULES.LIST.TABLE_HEADER.SCOPE'),
  t('LIVE_CHAT_RULES.LIST.TABLE_HEADER.REPLY_TIMEOUT'),
  t('LIVE_CHAT_RULES.LIST.TABLE_HEADER.EXTENSION'),
  t('LIVE_CHAT_RULES.LIST.TABLE_HEADER.ACTION'),
]);

onBeforeMount(() => {
  store.dispatch('liveChatRules/get');
  store.dispatch('projects/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('LIVE_CHAT_RULES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('LIVE_CHAT_RULES.HEADER')"
        :description="$t('LIVE_CHAT_RULES.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="$t('LIVE_CHAT_RULES.HEADER_BTN_TXT')"
            size="sm"
            :disabled="!canAddOverride"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable :headers="tableHeaders" :items="rows">
        <template #row="{ items }">
          <BaseTableRow
            v-for="rule in items"
            :key="rule.id ?? 'account-default'"
            :item="rule"
          >
            <template #default>
              <BaseTableCell>
                <div class="flex items-center gap-2">
                  <span class="text-body-main text-n-slate-12">
                    {{ scopeNameFor(rule) }}
                  </span>
                  <span
                    v-if="!rule.id"
                    class="px-1.5 py-0.5 text-xs rounded bg-n-slate-3 text-n-slate-11"
                  >
                    {{ $t('LIVE_CHAT_RULES.LIST.NOT_SAVED') }}
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{
                    $t('LIVE_CHAT_RULES.LIST.MINUTES', {
                      n: rule.replyTimeoutMinutes,
                    })
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell>
                <span class="text-body-main text-n-slate-11">
                  {{
                    $t('LIVE_CHAT_RULES.LIST.MINUTES', {
                      n: rule.extensionMinutes,
                    })
                  }}
                </span>
              </BaseTableCell>

              <BaseTableCell align="end">
                <div class="flex justify-end flex-shrink-0 gap-3">
                  <Button
                    v-tooltip.top="$t('LIVE_CHAT_RULES.FORM.EDIT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(rule)"
                  />
                  <Button
                    v-if="rule.id && rule.projectId"
                    v-tooltip.top="$t('LIVE_CHAT_RULES.FORM.DELETE')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    @click="openDeletePopup(rule)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>

    <woot-modal v-model:show="showFormPopup" :on-close="hideFormPopup">
      <LiveChatRuleForm
        v-if="selectedRule"
        :rule="selectedRule"
        @close="hideFormPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('LIVE_CHAT_RULES.DELETE.CONFIRM.TITLE')"
      :message="$t('LIVE_CHAT_RULES.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="$t('LIVE_CHAT_RULES.DELETE.CONFIRM.YES')"
      :reject-text="$t('LIVE_CHAT_RULES.DELETE.CONFIRM.NO')"
    />
  </SettingsLayout>
</template>
