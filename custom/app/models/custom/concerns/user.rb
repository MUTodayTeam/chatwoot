# A deleted staff member's status history goes with them. Removing them from one account only
# ends their open interval (Custom::AccountUser), since they may still work in another.
module Custom::Concerns::User
  extend ActiveSupport::Concern

  included do
    has_many :agent_status_events, dependent: :delete_all
  end
end
