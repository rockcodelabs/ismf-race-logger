# frozen_string_literal: true

# UserPolicy - Authorization rules for user management
#
# Only administrators can manage users.
#
# Permissions:
# - Admins: Full access (create, read, update, delete)
# - All other roles: No access
#
class UserPolicy < ApplicationPolicy
  # List all users
  # @return [Boolean]
  def index?
    admin?
  end

  # View user details
  # @return [Boolean]
  def show?
    admin?
  end

  # Create new user
  # @return [Boolean]
  def create?
    admin?
  end

  # Same as create
  def new?
    create?
  end

  # Update user
  # @return [Boolean]
  def update?
    admin?
  end

  # Same as update
  def edit?
    update?
  end

  # Delete user
  # Cannot delete yourself
  # @return [Boolean]
  def destroy?
    admin? && record != user
  end

  # Scope for listing users
  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
