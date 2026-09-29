# frozen_string_literal: true

FactoryBot.define do
  factory :case do
    conversation
    account { conversation.account }
    sequence(:display_id)
    subject { 'Cannot check in' }
  end
end
