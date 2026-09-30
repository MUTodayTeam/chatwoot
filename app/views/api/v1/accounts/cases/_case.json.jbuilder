conversation = record.conversation
json.id record.id
json.display_id record.display_id
json.display record.display
json.subject record.subject
json.severity record.severity
# The conversation's status: a case has none of its own. A chat the bot is still holding counts as Open.
json.status(conversation.pending? && conversation.inbox.active_bot? ? 'open' : conversation.status)
json.reopened_count record.reopened_count
json.created_at record.created_at.to_i
json.updated_at record.updated_at.to_i
json.project record.project&.slice(:id, :name, :color, :code)
json.team record.team&.slice(:id, :name)
# Picked when the case was solved; nil is "Other" once solved
json.category record.case_category&.slice(:id, :inquiry_type, :c1, :c2, :c3, :sla_respond_minutes, :sla_resolve_minutes)
json.summary record.summary
json.resolved_by record.resolved_by && { id: record.resolved_by.id, name: record.resolved_by.available_name }
json.conversation do
  json.id conversation.display_id
  json.inbox_id conversation.inbox_id
  # Set while an agent bot or Captain assistant holds the conversation, for the pending countdown
  json.assignee_type conversation.ai_assignee_type
  json.channel conversation.inbox.channel_type
  # The sweep's status clock (LiveChatRules::SweepJob::STATUS_CLOCK), for the auto-close countdown
  json.status_changed_at (conversation.status_changed_at || conversation.updated_at).to_i
end
json.contact do
  json.id conversation.contact.id
  json.name conversation.contact.name
  json.thumbnail conversation.contact.avatar_url
  json.company_name conversation.contact.additional_attributes['company_name']
end
# The owner is whoever the conversation is assigned to
if conversation.assignee
  json.owner do
    json.id conversation.assignee.id
    json.name conversation.assignee.available_name
    json.thumbnail conversation.assignee.avatar_url
  end
else
  json.owner nil
end
