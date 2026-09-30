import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import ContactAPI from 'dashboard/api/contacts';
import ContactChannels from '../ContactChannels.vue';

const lineInbox = {
  id: 1,
  name: 'Sample LINE OA',
  channel_type: 'Channel::Line',
};
const facebookInbox = {
  id: 2,
  name: 'Sample Page',
  channel_type: 'Channel::FacebookPage',
};

vi.mock('dashboard/composables/store', () => ({
  // The inboxes the user can access
  useMapGetter: () => ref([lineInbox, facebookInbox]),
}));
vi.mock('dashboard/api/contacts', () => ({
  default: { getConversations: vi.fn(), show: vi.fn() },
}));

describe('ContactChannels', () => {
  it('lists each inbox of the conversations the user may see, once', async () => {
    // The endpoint already drops conversations the user cannot see
    ContactAPI.getConversations.mockResolvedValue({
      data: {
        payload: [
          { id: 11, inbox_id: 1 },
          { id: 12, inbox_id: 1 },
        ],
      },
    });

    const wrapper = mount(ContactChannels, { props: { contactId: 7 } });
    await flushPromises();

    expect(ContactAPI.getConversations).toHaveBeenCalledWith(7);
    expect(ContactAPI.show).not.toHaveBeenCalled();
    expect(wrapper.findAll('span.truncate').map(row => row.text())).toEqual([
      'Sample LINE OA',
    ]);
  });
});
