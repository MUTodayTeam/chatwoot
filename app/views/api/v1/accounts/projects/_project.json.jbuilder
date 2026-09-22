json.id project.id
json.name project.name
json.description project.description
json.color project.color
json.avatar_url project.avatar_url
json.inbox_ids project.inboxes.map(&:id)
