json.id resource.id
# could be nil for a deleted agent hence the safe operator before account id
json.account_id Current.account&.id
availability_status = resource.availability_status
json.availability_status availability_status
# the status the agent picked, offline when they are not connected
json.agent_status availability_status == 'offline' ? 'offline' : resource.current_account_user&.agent_status
json.auto_offline resource.auto_offline
json.confirmed resource.confirmed?
json.email resource.email
json.provider resource.provider
json.available_name resource.available_name
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.name resource.name
json.role resource.role
json.thumbnail resource.avatar_url
json.developer resource.current_account_user&.developer || false
json.custom_role_id resource.current_account_user&.custom_role_id if ChatwootApp.enterprise?
