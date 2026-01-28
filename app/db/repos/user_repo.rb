# frozen_string_literal: true

# UserRepo - Repository for User data access (Hanami-style)
#
# Inherits from DB::Repo which provides:
# - find, find!, first, last, find_by (single record → Structs::User)
# - all, where, many (collections → Structs::UserSummary)
# - count, exists?, pluck (aggregates)
# - create, update, delete (CRUD)
#
# This repo only defines:
# - Custom query methods (authenticate, admins, referees, etc.)
# - base_scope override (eager loading, default ordering)
# - build_struct / build_summary (mapping record → struct)
#
# Example:
#   repo = UserRepo.new
#
#   user = repo.find(1)                         # => Structs::User (inherited)
#   user = repo.authenticate("a@b.com", "pwd")  # => Structs::User or nil
#   users = repo.admins                         # => [Structs::UserSummary, ...]
#
class UserRepo < DB::Repo
  # Configure the repo
  self.record_class = User
  self.struct_class = Structs::User
  self.summary_class = Structs::UserSummary

  # Document return types for reference
  returns_one :find_by_email, :authenticate
  returns_many :admins, :referees, :with_role, :search

  # ===========================================================================
  # CUSTOM SINGLE RECORD METHODS
  # ===========================================================================

  # Find user by email address
  def find_by_email(email)
    record = base_scope.find_by(email_address: email)
    to_struct(record)
  end

  # Authenticate user with email and password
  # Returns Structs::User if credentials are valid, nil otherwise
  def authenticate(email, password)
    record = User.find_by(email_address: email)
    return nil unless record

    # has_secure_password provides #authenticate method on the record
    authenticated = record.authenticate(password)
    return nil unless authenticated

    to_struct(record)
  end

  # ===========================================================================
  # CUSTOM COLLECTION METHODS
  # ===========================================================================

  # Return all admin users
  def admins
    base_scope
      .where(admin: true)
      .map { |record| to_summary(record) }
  end

  # Return all referees (national and international)
  def referees
    base_scope
      .joins(:role)
      .where(roles: { name: %w[national_referee international_referee] })
      .map { |record| to_summary(record) }
  end

  # Return users with a specific role
  def with_role(role_name)
    base_scope
      .joins(:role)
      .where(roles: { name: role_name })
      .map { |record| to_summary(record) }
  end

  # Search users by email or name (case-insensitive)
  def search(query)
    return [] if query.blank?

    pattern = "%#{query}%"
    base_scope
      .where("email_address ILIKE ? OR name ILIKE ?", pattern, pattern)
      .map { |record| to_summary(record) }
  end

  # ===========================================================================
  # CUSTOM AGGREGATE METHODS
  # ===========================================================================

  # Check if email exists
  def email_exists?(email)
    User.exists?(email_address: email)
  end

  # ===========================================================================
  # CRUD OVERRIDES (for role_name → role_id lookup)
  # ===========================================================================

  # Create a new user with role lookup
  def create(attrs)
    create_attrs = prepare_attrs_with_role(attrs)
    return nil unless create_attrs

    super(create_attrs)
  end

  # Update user with role lookup
  def update(id, attrs)
    update_attrs = prepare_attrs_with_role(attrs)
    return nil unless update_attrs

    super(id, update_attrs)
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with eager loading and ordering
  # This prevents N+1 queries and provides consistent ordering
  def base_scope
    User.includes(:role).order(created_at: :desc)
  end

  # Build a full struct from a User record
  def build_struct(record)
    Structs::User.new(
      id: record.id,
      email_address: record.email_address,
      name: record.name,
      admin: record.admin,
      role_name: record.role&.name,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build a summary struct from a User record
  def build_summary(record)
    Structs::UserSummary.new(
      id: record.id,
      email_address: record.email_address,
      name: record.name,
      admin: record.admin,
      role_name: record.role&.name
    )
  end

  private

  # Handle role_name → role_id lookup for create/update
  def prepare_attrs_with_role(attrs)
    return attrs unless attrs[:role_name]

    role = Role.find_by(name: attrs[:role_name])
    return nil unless role

    attrs.except(:role_name).merge(role_id: role.id)
  end
end