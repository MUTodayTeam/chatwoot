require 'rails_helper'

describe Integrations::Lark::SendOnLarkService do
  let(:account) { create(:account) }
  let(:hook) do
    create(:integrations_hook, account: account, app_id: 'lark',
                               settings: { 'webhook_url' => 'https://open.larksuite.com/open-apis/bot/v2/hook/abc123' })
  end
  let(:message) { create(:message, account: account, message_type: :incoming, content: 'สวัสดีครับ') }
  let(:conversation) { message.conversation }
  let(:service) { instance_double(described_class, perform: true) }

  # Lark reaches this service through two one-line entries in upstream files: an
  # INTEGRATION_PROCESSORS entry in HookJob and a supported_events_map entry in
  # HookListener. This fork syncs from upstream with a real merge rather than a
  # fast-forward, and both lines sit inside hashes upstream edits regularly — so a
  # conflict resolved in favour of upstream drops one line and takes team notifications
  # offline with nothing failing anywhere. These examples are the alarm for that.
  #
  # They live here, in a fork-owned spec mirroring the fork-owned service, rather than in
  # spec/jobs/hook_job_spec.rb or spec/listeners/hook_listener_spec.rb. That is deliberate
  # beyond keeping merge surface off upstream files: a guard sitting in the same upstream
  # file as the line it guards can be dropped by the very merge resolution it exists to
  # catch, and would then be silent exactly when it is needed.
  describe 'the wiring that carries an event to this service' do
    it 'is dispatched by HookJob on message.created' do
      allow(described_class).to receive(:new).and_return(service)

      HookJob.perform_now(hook, 'message.created', message: message)

      expect(described_class).to have_received(:new).with(message: message, hook: hook)
      expect(service).to have_received(:perform)
    end

    it 'is dispatched by HookJob on conversation.resolved, to clear the announcement' do
      allow(described_class).to receive(:clear_announcement)

      HookJob.perform_now(hook, 'conversation.resolved', conversation: conversation)

      expect(described_class).to have_received(:clear_announcement).with(conversation)
    end

    it 'is subscribed by HookListener to both events it handles' do
      listener = HookListener.instance

      expect(listener.send(:supported_hook_event?, hook, 'message.created')).to be(true)
      expect(listener.send(:supported_hook_event?, hook, 'conversation.resolved')).to be(true)
    end
  end
end
