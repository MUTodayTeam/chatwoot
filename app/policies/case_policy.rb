class CasePolicy < ApplicationPolicy
  def index?
    true
  end

  # A case is visible and editable to whoever can see its conversation
  def show?
    ConversationPolicy.new(user_context, record.conversation).show?
  end

  def update?
    show?
  end
end
