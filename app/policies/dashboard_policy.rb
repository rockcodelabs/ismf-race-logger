# frozen_string_literal: true

# DashboardPolicy - Authorization rules for admin dashboard
#
# The dashboard is only accessible to administrators.
#
class DashboardPolicy < ApplicationPolicy
  # View the admin dashboard
  # @return [Boolean]
  def index?
    admin?
  end

  def show?
    admin?
  end
end
