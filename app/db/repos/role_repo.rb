# frozen_string_literal: true

# RoleRepo - Repository for Role data access (Hanami-style)
#
# This is the public interface for role persistence.
# All query logic lives here, NOT in the Role model.
# Returns structs (immutable data objects), not ActiveRecord models.
#
# Example:
#   repo = RoleRepo.new
#
#   role = repo.find(1)              # => Structs::Role or nil
#   role = repo.find_by_name("admin") # => Structs::Role or nil
#   roles = repo.all                  # => [Structs::RoleSummary, ...]
#
class RoleRepo < DB::Repo
  # Configure the repo
  self.record_class = Role

  # Note: We use simple Data classes for roles since they're small
  # For now, we'll define inline structs until we create dedicated files

  # Document return types for reference
  returns_one :find, :find!, :first, :last, :find_by, :find_by_name, :create, :update
  returns_many :all, :where, :many

  # ===========================================================================
  # SINGLE RECORD METHODS
  # ===========================================================================

  # Find role by name
  def find_by_name(name)
    record = base_scope.find_by(name: name)
    to_struct(record)
  end

  # ===========================================================================
  # COLLECTION METHODS
  # ===========================================================================

  # Return all roles ordered by name
  def all
    base_scope.map { |record| to_summary(record) }
  end

  # ===========================================================================
  # AGGREGATE METHODS
  # ===========================================================================

  # Check if role name exists
  def name_exists?(name)
    Role.exists?(name: name)
  end

  # Get all role names
  def all_names
    Role.pluck(:name)
  end

  # ===========================================================================
  # PROTECTED: Mapping methods
  # ===========================================================================

  protected

  # Default scope with ordering
  def base_scope
    Role.order(:name)
  end

  # Build a full struct from a Role record
  # Using a simple Data class since Role is a simple entity
  def build_struct(record)
    RoleStruct.new(
      id: record.id,
      name: record.name,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build a summary struct from a Role record
  def build_summary(record)
    RoleSummary.new(
      id: record.id,
      name: record.name
    )
  end

  # Simple struct for single role (inline definition)
  RoleStruct = Data.define(:id, :name, :created_at, :updated_at)

  # Summary struct for role collections
  RoleSummary = Data.define(:id, :name)
end