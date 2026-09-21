# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    # Assigned to the same user the notification belongs to: every notification
    # type points at a conversation, and My Inbox only lists the ones assigned to
    # the reader, so an unassigned conversation here would make fixtures invisible.
    primary_actor { create(:conversation, account: account, assignee: user) }
    notification_type { 'conversation_assignment' }
    user
    account
    read_at { nil }
    snoozed_until { nil }
  end

  trait :read do
    read_at { DateTime.now.utc - 3.days }
  end

  trait :snoozed do
    snoozed_until { DateTime.now.utc + 3.days }
  end
end
