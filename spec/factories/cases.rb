# frozen_string_literal: true

FactoryBot.define do
  factory :case do
    conversation
    account { conversation.account }
    # Next in the account, as Case.open_for! numbers them, so it follows the cases a resolve opened
    display_id { Case.where(account_id: account.id).maximum(:display_id).to_i + 1 }
    subject { 'Cannot check in' }
  end
end
