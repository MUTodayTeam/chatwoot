json.team @team ? { id: @team.id, name: @team.name } : nil
json.agents @agents do |agent|
  json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
end
json.handler @handler ? { user_id: @handler.user_id, started_at: @handler.started_at.to_i } : nil
