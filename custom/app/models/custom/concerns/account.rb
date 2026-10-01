# Developers keep their role's permissions but are never picked by automatic assignment,
# so every automatic path reads their ids from here.
module Custom::Concerns::Account
  def developer_user_ids
    account_users.where(developer: true).pluck(:user_id)
  end
end
