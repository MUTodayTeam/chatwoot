json.conversation_id @conversation.display_id
json.assignee do
  json.partial! 'api/v1/models/agent', formats: [:json], resource: @assignee
end
