json.array! @live_chat_rules do |live_chat_rule|
  json.partial! 'live_chat_rule', live_chat_rule: live_chat_rule
end
