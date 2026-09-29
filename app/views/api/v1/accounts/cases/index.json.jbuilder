json.meta do
  json.count @count
  json.open_count @open_count
  json.current_page @cases.current_page
end
json.payload do
  json.array! @cases, partial: 'api/v1/accounts/cases/case', as: :record
end
