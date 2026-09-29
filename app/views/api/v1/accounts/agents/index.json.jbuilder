json.array! @agents do |agent|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
  json.conversation_load @agent_loads[agent.id] if @agent_loads
end
