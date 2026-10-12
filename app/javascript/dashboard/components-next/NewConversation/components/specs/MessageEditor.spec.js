import { mount, shallowMount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import MessageEditor from '../MessageEditor.vue';
import ComposeNewConversationForm from '../ComposeNewConversationForm.vue';

const i18n = withFullI18n();

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

const EditorStub = {
  props: ['placeholder', 'modelValue'],
  template: '<div class="editor-stub" :data-placeholder="placeholder" />',
};

const mountEditor = (props = {}) =>
  mount(MessageEditor, {
    props: { modelValue: '', ...props },
    global: {
      stubs: { Editor: EditorStub, CopilotEditorSection: true },
    },
  });

describe('MessageEditor', () => {
  it('uses the compose placeholder and full height by default', () => {
    const editor = mountEditor().find('.editor-stub');

    expect(editor.attributes('data-placeholder')).toBe(
      i18n.global.t('COMPOSE_NEW_CONVERSATION.FORM.MESSAGE_EDITOR.PLACEHOLDER')
    );
    expect(editor.classes()).toContain(
      '[&_.ProseMirror-woot-style]:!min-h-[12rem]'
    );
  });

  it('accepts a custom placeholder and a compact height', () => {
    const editor = mountEditor({
      placeholder: 'Add a message',
      compact: true,
    }).find('.editor-stub');

    expect(editor.attributes('data-placeholder')).toBe('Add a message');
    expect(editor.classes()).toContain(
      '[&_.ProseMirror-woot-style]:!min-h-[4rem]'
    );
    expect(editor.classes()).not.toContain(
      '[&_.ProseMirror-woot-style]:!min-h-[12rem]'
    );
  });

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
