<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useEmitter } from 'dashboard/composables/emitter';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useConversationRequiredAttributes } from 'dashboard/composables/useConversationRequiredAttributes';
import wootConstants from 'dashboard/constants/globals';
import {
  CMD_REOPEN_CONVERSATION,
  CMD_RESOLVE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';
import {
  BOT_STATUS_ICON,
  LIFECYCLE_STATUS,
  SELECTABLE_STATUSES,
  canChangeTo,
  canSnoozeUntil,
  getLifecycleStatus,
} from 'dashboard/helper/conversationLifecycle';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import ConversationResolveAttributesModal from 'dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue';
import SelectCategoryDialog from 'dashboard/components-next/Cases/SelectCategoryDialog.vue';

const { STATUS_TYPE } = wootConstants;
const SNOOZE_UNTIL_ACTION = 'snooze_until';

const { t } = useI18n();
const store = useStore();
const { checkMissingAttributes } = useConversationRequiredAttributes();

const isLoading = ref(false);
const resolveAttributesModalRef = ref(null);
const selectCategoryDialogRef = ref(null);
const isSolving = ref(false);
// Required attributes filled in before the category is picked, saved with the solve
const solveCustomAttributes = ref(null);
const showDropdown = ref(false);
const toggleDropdown = (value = !showDropdown.value) => {
  showDropdown.value = value;
};

const currentChat = useMapGetter('getSelectedChat');

const lifecycleStatus = computed(() => getLifecycleStatus(currentChat.value));
const isClosed = computed(
  () => currentChat.value.status === STATUS_TYPE.CLOSED
);

const statusLabel = value =>
  t(`CONVERSATION.STATUS_DROPDOWN.STATUSES.${value}`);

const menuSections = computed(() => {
  const statusItems = SELECTABLE_STATUSES.map(({ value, icon }) => ({
    action: 'status',
    value,
    icon,
    label: statusLabel(value),
    isSelected: lifecycleStatus.value === value,
    disabled: !canChangeTo(currentChat.value, value),
  }));

  // Bot is shown while a bot holds the conversation; agents take it over by picking Open.
  if (lifecycleStatus.value === LIFECYCLE_STATUS.BOT) {
    statusItems.unshift({
      action: 'status',
      value: LIFECYCLE_STATUS.BOT,
      icon: BOT_STATUS_ICON,
      label: statusLabel(LIFECYCLE_STATUS.BOT),
      isSelected: true,
      disabled: true,
    });
  }

  const sections = [{ items: statusItems }];
  if (canSnoozeUntil(currentChat.value)) {
    sections.push({
      items: [
        {
          action: SNOOZE_UNTIL_ACTION,
          value: SNOOZE_UNTIL_ACTION,
          icon: 'i-lucide-alarm-clock',
          label: t('CONVERSATION.STATUS_DROPDOWN.SNOOZE_UNTIL'),
        },
      ],
    });
  }
  return sections;
});

const changeStatus = async (
  status,
  snoozedUntil = null,
  customAttributes = null
) => {
  isLoading.value = true;
  try {
    await store.dispatch('toggleStatus', {
      conversationId: currentChat.value.id,
      status,
      snoozedUntil,
      customAttributes,
    });
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
  } catch (error) {
    // A refused change, such as closing a conversation that is no longer resolved.
    useAlert(error.message || t('CONVERSATION.CHANGE_STATUS_FAILED'));
  } finally {
    isLoading.value = false;
  }
};

const resolveConversation = () => {
  if (isClosed.value) return;

  const currentCustomAttributes = currentChat.value.custom_attributes || {};
  const { hasMissing, missing } = checkMissingAttributes(
    currentCustomAttributes
  );

  if (hasMissing) {
    resolveAttributesModalRef.value?.open(missing, currentCustomAttributes, {
      id: currentChat.value.id,
      snoozedUntil: null,
    });
  } else {
    changeStatus(STATUS_TYPE.RESOLVED);
  }
};

const openSelectCategory = (customAttributes = null) => {
  solveCustomAttributes.value = customAttributes;
  selectCategoryDialogRef.value?.open(
    currentChat.value.case?.case_category_id ?? null
  );
};

// Solved from the menu asks for the category the case is filed under (spec 7.3)
const solveConversation = () => {
  if (isClosed.value) return;

  const currentCustomAttributes = currentChat.value.custom_attributes || {};
  const { hasMissing, missing } = checkMissingAttributes(
    currentCustomAttributes
  );

  if (hasMissing) {
    resolveAttributesModalRef.value?.open(missing, currentCustomAttributes, {
      id: currentChat.value.id,
      snoozedUntil: null,
      selectCategory: true,
    });
  } else {
    openSelectCategory();
  }
};

const onSolve = async ({ caseCategoryId, summary, sendSurvey }) => {
  isSolving.value = true;
  try {
    await store.dispatch('solveConversation', {
      conversationId: currentChat.value.id,
      caseCategoryId,
      summary,
      sendSurvey,
      customAttributes: solveCustomAttributes.value,
    });
    selectCategoryDialogRef.value?.close();
    useAlert(t('CONVERSATION.CHANGE_STATUS'));
  } catch (error) {
    useAlert(error.message || t('CONVERSATION.CHANGE_STATUS_FAILED'));
  } finally {
    isSolving.value = false;
  }
};

const handleResolveWithAttributes = ({ attributes, context }) => {
  if (!context) return;

  const currentCustomAttributes = currentChat.value.custom_attributes || {};
  const customAttributes = { ...currentCustomAttributes, ...attributes };
  if (context.selectCategory) {
    openSelectCategory(customAttributes);
    return;
  }
  changeStatus(STATUS_TYPE.RESOLVED, context.snoozedUntil, customAttributes);
};

const reopenConversation = () => changeStatus(STATUS_TYPE.OPEN);

const openSnoozeModal = () => {
  document.querySelector('ninja-keys')?.open({ parent: 'snooze_conversation' });
};

const onMenuAction = ({ action, value }) => {
  toggleDropdown(false);

  if (action === SNOOZE_UNTIL_ACTION) {
    openSnoozeModal();
    return;
  }
  if (value === lifecycleStatus.value) return;

  if (value === LIFECYCLE_STATUS.SOLVED) {
    solveConversation();
    return;
  }

  const { status } = SELECTABLE_STATUSES.find(item => item.value === value);
  changeStatus(status);
};

const getConversationParams = () => {
  const allConversations = document.querySelectorAll(
    '.conversations-list .conversation'
  );
  const activeConversation = document.querySelector(
    'div.conversations-list div.conversation.active'
  );

  return {
    all: allConversations,
    activeIndex: [...allConversations].indexOf(activeConversation),
    lastIndex: allConversations.length - 1,
  };
};

useKeyboardEvents({
  'Alt+KeyM': {
    action: () => toggleDropdown(),
    allowOnFocusedInput: true,
  },
  'Alt+KeyE': {
    action: event => {
      // Chrome on Windows treats Alt+E as a legacy shortcut for its own menu, so
      // without preventDefault that menu opens on top of the resolve.
      event.preventDefault();
      resolveConversation();
    },
  },
  '$mod+Alt+KeyE': {
    action: event => {
      const { all, activeIndex, lastIndex } = getConversationParams();
      resolveConversation();

      if (activeIndex < lastIndex) {
        all[activeIndex + 1].click();
      } else if (all.length > 1) {
        all[0].click();
        document.querySelector('.conversations-list').scrollTop = 0;
      }
      event.preventDefault();
    },
  },
});

useEmitter(CMD_REOPEN_CONVERSATION, reopenConversation);
useEmitter(CMD_RESOLVE_CONVERSATION, resolveConversation);
</script>

<template>
  <div
    v-on-clickaway="() => toggleDropdown(false)"
    class="relative flex items-center"
  >
    <Button
      v-tooltip.top="$t('CONVERSATION.STATUS_DROPDOWN.TOOLTIP')"
      :label="statusLabel(lifecycleStatus)"
      icon="i-lucide-chevron-down"
      trailing-icon
      size="sm"
      no-animation
      class="min-w-[9.375rem] !justify-between"
      :is-loading="isLoading"
      :disabled="isLoading"
      @click="toggleDropdown()"
    />
    <DropdownMenu
      v-if="showDropdown"
      :menu-sections="menuSections"
      class="mt-1 top-full end-0 min-w-[9.375rem]"
      @action="onMenuAction"
    />
    <ConversationResolveAttributesModal
      ref="resolveAttributesModalRef"
      @submit="handleResolveWithAttributes"
    />
    <SelectCategoryDialog
      ref="selectCategoryDialogRef"
      :is-loading="isSolving"
      @solve="onSolve"
    />
  </div>
</template>
