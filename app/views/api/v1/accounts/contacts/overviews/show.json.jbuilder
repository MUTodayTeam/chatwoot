json.conversations_count @conversations_count
json.first_contact_at @first_contact_at&.to_i
if @latest_conversation
  json.latest_conversation do
    json.id @latest_conversation.display_id
    json.status @latest_conversation.status
  end
else
  json.latest_conversation nil
end
json.history @history do |conversation|
  kase = conversation.case
  # Whoever solved it, else whoever it was assigned to
  agent = kase&.resolved_by || conversation.assignee
  json.id conversation.display_id
  json.status conversation.status
  json.created_at conversation.created_at.to_i
  json.topic kase ? kase.subject : Case.subject_from(conversation.messages.incoming.reorder(:created_at, :id).first)
  json.case kase&.push_event_data
  json.project conversation.inbox.project&.slice(:id, :name, :color, :code)
  json.channel conversation.inbox.channel_type
  json.agent agent ? { id: agent.id, name: agent.available_name } : nil
  json.bot conversation.assignee_agent_bot_id.present?
  json.missed conversation.missed_at.present?
end
