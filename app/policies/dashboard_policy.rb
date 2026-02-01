# frozen_string_literal: true

# DashboardPolicy - Authorization rules for admin dashboard
#
# The dashboard is accessible to administrators and management roles
# (var_operator, jury_president, referee_manager).
#
class DashboardPolicy < ApplicationPolicy
  # View the admin dashboard
  # @return [Boolean]
  def index?
    can_manage?
  end

  def show?
    can_manage?
  end
end
