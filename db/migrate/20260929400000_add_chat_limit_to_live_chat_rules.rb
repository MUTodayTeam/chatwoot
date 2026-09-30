# frozen_string_literal: true

class AddChatLimitToLiveChatRules < ActiveRecord::Migration[7.1]
  def change
    add_column :live_chat_rules, :chat_limit, :integer, default: 10, null: false
  end
end
