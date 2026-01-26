# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Helper methods for common role checks
  def admin?
    user&.admin?
  end

  def referee?
    user&.referee?
  end

  def var_operator?
    user&.var_operator?
  end

  def jury_president?
    user&.jury_president?
  end

  def referee_manager?
    user&.referee_manager?
  end

  def broadcast_viewer?
    user&.broadcast_viewer?
  end

  def national_referee?
    user&.national_referee?
  end

  def international_referee?
    user&.international_referee?
  end

  # Check if user can manage (admin-level operations)
  def can_manage?
    admin? || jury_president? || referee_manager?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    # Helper methods available in scope classes
    def admin?
      user&.admin?
    end

    def referee?
      user&.referee?
    end

    def var_operator?
      user&.var_operator?
    end

    def jury_president?
      user&.jury_president?
    end

    def referee_manager?
      user&.referee_manager?
    end

    def broadcast_viewer?
      user&.broadcast_viewer?
    end

    def can_manage?
      admin? || jury_president? || referee_manager?
    end
  end
end