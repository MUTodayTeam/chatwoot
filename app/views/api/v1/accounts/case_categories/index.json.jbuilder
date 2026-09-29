json.payload do
  json.array! @case_categories, partial: 'case_category', as: :case_category
end
