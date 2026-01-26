# frozen_string_literal: true

# Base policy class with performance-optimized role checking.
#
# Performance patterns applied (from 37signals style guide):
# - Memoization: Cache role checks to avoid repeated method calls
# - In-memory checks: All role checks use in-memory comparisons, no DB queries
# - Single role lookup: Cache the user's role name once, compare strings
#
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

  private

  # Memoized role name - single lookup, reused for all checks
  # Avoids repeated role&.name calls throughout policy
  def user_role_name
    @user_role_name ||= user&.role&.name
  end

  # Memoized admin check
  def admin?
    return @admin if defined?(@admin)
    @admin = user&.admin? || false
  end

  # Fast in-memory role checks using cached role name
  def referee?
    return @referee if defined?(@referee)
    @referee = user_role_name.in?(%w[national_referee international_referee])
  end

  def var_operator?
    return @var_operator if defined?(@var_operator)
    @var_operator = user_role_name == "var_operator"
  end

  def jury_president?
    return @jury_president if defined?(@jury_president)
    @jury_president = user_role_name == "jury_president"
  end

  def referee_manager?
    return @referee_manager if defined?(@referee_manager)
    @referee_manager = user_role_name == "referee_manager"
  end

  def broadcast_viewer?
    return @broadcast_viewer if defined?(@broadcast_viewer)
    @broadcast_viewer = user_role_name == "broadcast_viewer"
  end

  def national_referee?
    return @national_referee if defined?(@national_referee)
    @national_referee = user_role_name == "national_referee"
  end

  def international_referee?
    return @international_referee if defined?(@international_referee)
    @international_referee = user_role_name == "international_referee"
  end

  # Memoized management check - combines multiple role checks
  def can_manage?
    return @can_manage if defined?(@can_manage)
    @can_manage = admin? || jury_president? || referee_manager?
  end

  # Check if user can create reports/incidents (field operations)
  def can_report?
    return @can_report if defined?(@can_report)
    @can_report = referee? || var_operator? || can_manage?
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

    # Memoized role name for scope - single lookup
    def user_role_name
      @user_role_name ||= user&.role&.name
    end

    def admin?
      return @admin if defined?(@admin)
      @admin = user&.admin? || false
    end

    def referee?
      return @referee if defined?(@referee)
      @referee = user_role_name.in?(%w[national_referee international_referee])
    end

    def var_operator?
      return @var_operator if defined?(@var_operator)
      @var_operator = user_role_name == "var_operator"
    end

    def jury_president?
      return @jury_president if defined?(@jury_president)
      @jury_president = user_role_name == "jury_president"
    end

    def referee_manager?
      return @referee_manager if defined?(@referee_manager)
      @referee_manager = user_role_name == "referee_manager"
    end

    def broadcast_viewer?
      return @broadcast_viewer if defined?(@broadcast_viewer)
      @broadcast_viewer = user_role_name == "broadcast_viewer"
    end

    def national_referee?
      return @national_referee if defined?(@national_referee)
      @national_referee = user_role_name == "national_referee"
    end

    def international_referee?
      return @international_referee if defined?(@international_referee)
      @international_referee = user_role_name == "international_referee"
    end

    def can_manage?
      return @can_manage if defined?(@can_manage)
      @can_manage = admin? || jury_president? || referee_manager?
    end

    def can_report?
      return @can_report if defined?(@can_report)
      @can_report = referee? || var_operator? || can_manage?
    end
  end
end