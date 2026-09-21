json.id project.id
json.name project.name
json.description project.description
json.color project.color
json.inbox_ids project.inboxes.map(&:id)
