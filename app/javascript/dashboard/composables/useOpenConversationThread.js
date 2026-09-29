import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { CASE_FINISHED_STATUSES } from 'dashboard/helper/caseHelper';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';

// Marks a thread opened only to be read; MessagesView hides the composer while it stays Solved or Closed
export const READ_ONLY_QUERY = 'read_only';

/**
 * Opens a conversation by display id. A Solved or Closed thread is not in the
 * default list, so the list opens on its status.
 * @returns {(conversation: { id: number, status: string }, options?: { readOnly?: boolean }) => void}
 */
export function useOpenConversationThread() {
  const router = useRouter();
  const accountId = useMapGetter('getCurrentAccountId');
  const { uiSettings, updateUISettings } = useUISettings();

  return ({ id, status }, { readOnly = false } = {}) => {
    if (CASE_FINISHED_STATUSES.includes(status)) {
      updateUISettings({
        conversations_filter_by: {
          ...uiSettings.value.conversations_filter_by,
          status,
        },
      });
    }
    router.push({
      path: frontendURL(conversationUrl({ accountId: accountId.value, id })),
      query: readOnly ? { [READ_ONLY_QUERY]: 'true' } : {},
    });
  };
}
