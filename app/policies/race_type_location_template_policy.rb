# frozen_string_literal: true

# RaceTypeLocationTemplatePolicy - Authorization rules for race type location template management
#
# Permissions:
# - Admins: Full access (create, read, update, delete, reorder)
# - Others: No access (templates affect future races, so only admins should modify)
#
# Business Rules:
# - Only admins can manage templates
# - Changes to templates only affect future races (existing races unchanged)
# - Deleting templates doesn't affect existing race locations
#
class RaceTypeLocationTemplatePolicy < ApplicationPolicy
  # List templates for a race type
  # @return [Boolean]
  def index?
    admin?
  end

  # View template details
  # @return [Boolean]
  def show?
    admin?
  end

  # Create new template
  # @return [Boolean]
  def create?
    admin?
  end

  # Same as create
  def new?
    create?
  end

  # Update template
  # @return [Boolean]
  def update?
    admin?
  end

  # Same as update
  def edit?
    update?
  end

  # Delete template
  # @return [Boolean]
  def destroy?
    admin?
  end

  # Reorder templates
  # @return [Boolean]
  def reorder?
    admin?
  end

  # Scope for listing templates
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