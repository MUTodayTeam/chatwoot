# Announces a conversation to Lark once the customer has waited past the reply
# deadline — the moment the countdown in the dashboard turns red. Nothing fires an
# event when a deadline passes, so this runs on a schedule instead.
class Integrations::Lark::AnnounceOverdueConversationsJob < ApplicationJob
  queue_as :low

  def perform
    Integrations::Hook.where(app_id: 'lark', status: :enabled).find_each do |hook|
      announce_for(hook)
    end
  end

  private

  def announce_for(hook)
    overdue_conversations(hook.account).find_each do |conversation|
      message = conversation.messages.incoming.last
      next if message.blank?

      Integrations::Lark::SendOnLarkService.new(message: message, hook: hook).perform
    end
  end

  # Still open, still waiting on us, past the deadline, and not announced yet.
  # SendOnLarkService writes the marker, so an announced conversation drops out
  # here and is only announced again after it is resolved and reopened.
  def overdue_conversations(account)
    account.conversations
           .open
           .where.not(waiting_since: nil)
           .where(reply_due_at: ...Time.current)
           .where("COALESCE(additional_attributes ->> 'lark_announced_at', '') = ''")
  end
end
