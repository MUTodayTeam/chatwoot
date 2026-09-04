require 'rails_helper'

RSpec.describe MutodayFaqReplyJob do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :mutoday_faq_reply, account: account) }
  let(:inbox) { hook.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  end
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :incoming, sender: contact, content: 'อยากส่งข่าวต้องทำยังไง')
  end

  # This feature reaches its job through two one-line entries in upstream files: an
  # INTEGRATION_PROCESSORS entry in HookJob and a supported_events_map entry in
  # HookListener. Nothing else in the suite touches either, and this fork syncs from
  # upstream with a real merge rather than a fast-forward — so a conflict resolved in
  # favour of upstream would drop one line, take the whole feature silently offline, and
  # leave every other example green. These two are the alarm for that.
  #
  # They are here rather than appended to spec/jobs/hook_job_spec.rb and
  # spec/listeners/hook_listener_spec.rb because SPEC rule 28 puts both of those upstream
  # files off limits. This file mirrors app/jobs/mutoday_faq_reply_job.rb and is ours.
  describe 'the wiring that carries a LINE message to this job' do
    it 'is dispatched by HookJob on message.created' do
      expect { HookJob.perform_now(hook, 'message.created', message: message) }
        .to have_enqueued_job(described_class).with(hook, message).on_queue('high')
    end

    it 'is subscribed to message.created by HookListener' do
      expect(HookListener.instance.send(:supported_hook_event?, hook, 'message.created')).to be(true)
    end
  end
end
