conversation = record.conversation
json.id record.id
json.display_id record.display_id
json.display record.display
json.subject record.subject
json.severity record.severity
# The conversation's status: a case has none of its own
json.status conversation.status
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
  json.channel conversation.inbox.channel_type
end
json.contact do
  json.id conversation.contact.id
  json.name conversation.contact.name
  json.thumbnail conversation.contact.avatar_url
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
