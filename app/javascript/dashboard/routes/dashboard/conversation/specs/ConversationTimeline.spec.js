import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import ConversationTimeline from '../ConversationTimeline.vue';

withFullI18n();

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref(() => ({ name: 'Checkin+ LINE OA' })),
}));

describe('ConversationTimeline', () => {
  it('lists the events newest first with a dot per kind', () => {
    const wrapper = mount(ConversationTimeline, {
      props: {
        chat: {
          inbox_id: 3,
          created_at: 1_800_000_000,
          messages: [
            {
              id: 5,
              message_type: 2,
              content: 'Assigned to Jason by Beam',
              created_at: 1_800_000_060,
              content_attributes: { activity: { type: 'assignee_changed' } },
            },
            {
              id: 6,
              message_type: 2,
              content: 'Case #CK-1 opened automatically',
              created_at: 1_800_000_061,
              content_attributes: { activity: { type: 'case_opened' } },
            },
          ],
        },
      },
    });

    const rows = wrapper.findAll('li');
    expect(rows.map(row => row.find('p').text())).toEqual([
      'Case #CK-1 opened automatically',
      'Assigned to Jason by Beam',
      'Arrived via Checkin+ LINE OA',
    ]);
    expect(rows.map(row => row.find('span').classes())).toEqual([
      expect.arrayContaining(['bg-n-ruby-9']),
      expect.arrayContaining(['bg-n-slate-12']),
      expect.arrayContaining(['bg-n-slate-8']),
    ]);
  });
});
