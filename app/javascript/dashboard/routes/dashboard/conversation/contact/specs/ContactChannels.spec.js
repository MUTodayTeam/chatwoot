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
  default: { getChannels: vi.fn() },
}));

const contactInbox = (id, name) => ({
  source_id: `src-${id}`,
  inbox: { id, name },
});

describe('ContactChannels', () => {
  it('lists each accessible inbox the contact is linked to once and hides the rest', async () => {
    ContactAPI.getChannels.mockResolvedValue({
      data: {
        payload: {
          id: 7,
          contact_inboxes: [
            contactInbox(1, 'Sample LINE OA'),
            contactInbox(1, 'Sample LINE OA'),
            contactInbox(3, 'Inbox the agent cannot open'),
          ],
        },
      },
    });

    const wrapper = mount(ContactChannels, { props: { contactId: 7 } });
    await flushPromises();

    expect(ContactAPI.getChannels).toHaveBeenCalledWith(7);
    expect(wrapper.findAll('span.truncate').map(row => row.text())).toEqual([
      'Sample LINE OA',
    ]);
  });
});
