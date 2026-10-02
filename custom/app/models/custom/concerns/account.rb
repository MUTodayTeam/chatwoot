# Developers keep their role's permissions but are never picked by automatic assignment,
# so every automatic path reads their ids from here.
module Custom::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :agent_status_events, dependent: :delete_all
  end

  def developer_user_ids
    account_users.where(developer: true).pluck(:user_id)
  end
end
