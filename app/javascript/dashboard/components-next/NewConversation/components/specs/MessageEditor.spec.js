import { mount, shallowMount } from '@vue/test-utils';
import { withFullI18n } from '../../../../../../../vitest.i18n';
import MessageEditor from '../MessageEditor.vue';
import ComposeNewConversationForm from '../ComposeNewConversationForm.vue';

withFullI18n();

vi.mock('dashboard/components/widgets/WootWriter/Editor.vue', () => ({
  default: {
    name: 'WootEditorStub',
    props: ['inboxId'],
    template: '<div />',
  },
}));
vi.mock(
  'dashboard/components/widgets/conversation/CopilotEditorSection.vue',
  () => ({ default: { template: '<div />' } })
);
vi.mock('dashboard/composables/useCopilotReply', () => ({
  useCopilotReply: () => ({}),
}));
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: () => {},
}));

describe('New conversation message editor', () => {
  it("hands the target inbox to the editor so '/' offers only its project's replies", () => {
    const form = shallowMount(ComposeNewConversationForm, {
      props: {
        targetInbox: { id: 3, channelType: 'Channel::Api', medium: '' },
        selectedContact: {
          id: 1,
          contactInboxes: [
            { id: 3, name: 'Checkin+', channelType: 'Channel::Api' },
          ],
        },
        contactsUiFlags: {},
        contactConversationsUiFlags: {},
        formState: { message: '', attachedFiles: [] },
      },
    });
    expect(form.findComponent(MessageEditor).props('inboxId')).toBe(3);

    const editor = mount(MessageEditor, { props: { inboxId: 3 } });
    expect(
      editor.findComponent({ name: 'WootEditorStub' }).props('inboxId')
    ).toBe(3);
  });
});
