import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { CASE_FINISHED_STATUSES } from 'dashboard/helper/caseHelper';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';

/**
 * Opens a conversation by display id. A Solved or Closed thread is not in the
 * default list, so the list opens on its status.
 * @returns {(conversation: { id: number, status: string }) => void}
 */
export function useOpenConversationThread() {
  const router = useRouter();
  const accountId = useMapGetter('getCurrentAccountId');
  const { uiSettings, updateUISettings } = useUISettings();

  return ({ id, status }) => {
    if (CASE_FINISHED_STATUSES.includes(status)) {
      updateUISettings({
        conversations_filter_by: {
          ...uiSettings.value.conversations_filter_by,
          status,
        },
      });
    }
    router.push(
      frontendURL(conversationUrl({ accountId: accountId.value, id }))
    );
  };
}
