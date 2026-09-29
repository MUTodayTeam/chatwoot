# Agents read the categories to solve with; administrators manage them
class CaseCategoryPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def template?
    create?
  end

  def export?
    create?
  end

  def import?
    create?
  end
end
