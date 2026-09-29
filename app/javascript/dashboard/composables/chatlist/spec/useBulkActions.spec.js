import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useBulkActions } from '../useBulkActions';

const dispatch = vi.fn();
const selectedIds = ref([]);
const conversations = {
  1: { id: 1, status: 'open', custom_attributes: {} },
  2: { id: 2, status: 'closed', custom_attributes: {} },
  3: { id: 3, status: 'closed', custom_attributes: {} },
};

vi.mock('vuex', () => ({
  useStore: () => ({
    dispatch,
    getters: { getConversationById: id => conversations[id] },
  }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => selectedIds,
}));
vi.mock('dashboard/composables/useConversationRequiredAttributes', () => ({
  useConversationRequiredAttributes: () => ({
    checkMissingAttributes: () => ({ hasMissing: false, missing: [] }),
  }),
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, named) => (named ? `${key}:${named.n}` : key),
  }),
}));

const processCalls = () =>
  dispatch.mock.calls.filter(([action]) => action === 'bulkActions/process');

describe('useBulkActions', () => {
  describe('#onUpdateConversations', () => {
    beforeEach(() => {
      dispatch.mockResolvedValue();
      selectedIds.value = [1, 2, 3];
    });

    it('skips closed conversations when resolving and reports how many', async () => {
      await useBulkActions().onUpdateConversations('resolved', null);

      expect(processCalls()).toEqual([
        [
          'bulkActions/process',
          {
            type: 'Conversation',
            ids: [1],
            fields: { status: 'resolved' },
            snoozed_until: null,
          },
        ],
      ]);
      expect(useAlert).toHaveBeenCalledWith(
        'BULK_ACTION.UPDATE.CLOSED_SKIPPED:2'
      );
      expect(useAlert).not.toHaveBeenCalledWith(
        'BULK_ACTION.UPDATE.UPDATE_SUCCESFUL'
      );
    });

    it('skips closed conversations when snoozing', async () => {
      await useBulkActions().onUpdateConversations('snoozed', 1700000000);

      expect(processCalls()[0][1].ids).toEqual([1]);
      expect(useAlert).toHaveBeenCalledWith(
        'BULK_ACTION.UPDATE.CLOSED_SKIPPED:2'
      );
    });

    it('sends nothing when every selected conversation is closed', async () => {
      selectedIds.value = [2, 3];

      await useBulkActions().onUpdateConversations('resolved', null);

      expect(processCalls()).toEqual([]);
      expect(useAlert).toHaveBeenCalledWith(
        'BULK_ACTION.UPDATE.CLOSED_SKIPPED:2'
      );
    });

    it('reopens closed conversations along with the rest', async () => {
      await useBulkActions().onUpdateConversations('open', null);

      expect(processCalls()[0][1].ids).toEqual([1, 2, 3]);
      expect(useAlert).toHaveBeenCalledWith(
        'BULK_ACTION.UPDATE.UPDATE_SUCCESFUL'
      );
    });
  });
});
