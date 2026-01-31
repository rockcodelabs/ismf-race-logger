# frozen_string_literal: true

# PenaltyPolicy - Authorization rules for penalty management
#
# Penalties are rule-based time additions or disqualifications.
# Only administrators and VAR operators can manage penalties.
#
# Permissions:
# - Admins: Full access (create, read, update, delete)
# - VAR Operators: Full access (create, read, update, delete)
# - All other roles: No access
#
class PenaltyPolicy < ApplicationPolicy
  # List all penalties
  # @return [Boolean]
  def index?
    admin? || var_operator?
  end

  # View penalty details
  # @return [Boolean]
  def show?
    admin? || var_operator?
  end

  # Create new penalty
  # @return [Boolean]
  def create?
    admin? || var_operator?
  end

  # Same as create
  def new?
    create?
  end

  # Update penalty
  # @return [Boolean]
  def update?
    admin? || var_operator?
  end

  # Same as update
  def edit?
    update?
  end

  # Delete penalty
  # @return [Boolean]
  def destroy?
    admin?
  end

  # Scope for listing penalties
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin? || var_operator?
        scope.all
      else
        scope.none
      end
    end
  end
end
