# frozen_string_literal: true

# Repository for {{Resource}} persistence operations
#
# Usage:
#   repo = AppContainer["repos.{{resource}}"]
#   repo.find(1)           # => Structs::{{Resource}} or nil
#   repo.find!(1)          # => Structs::{{Resource}} or raises
#   repo.all               # => [Structs::{{Resource}}Summary, ...]
#   repo.find_by_{{field}}(value) # => Structs::{{Resource}} or nil
#
class {{Resource}}Repo < DB::Repo
  # Declare which custom methods return single vs. collection
  returns_one :find_by_{{field}}
  returns_many :all_active, :search

  # --- Single Record Methods ---

  def find_by_{{field}}({{field}})
    find_by({{field}}: {{field}})
  end

  # --- Collection Methods ---

  def all_active
    where(status: "active")
  end

  def search(query)
    base_scope
      .where("name ILIKE ?", "%#{query}%")
      .map { |r| build_summary(r) }
  end

  protected

  # Override base scope to include associations
  def base_scope
    {{Resource}}.includes(:association_name)
  end

  # Build full struct for single record operations
  def build_struct(record)
    Structs::{{Resource}}.new(
      id: record.id,
      name: record.name,
      status: record.status,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  # Build summary struct for collection operations
  def build_summary(record)
    Structs::{{Resource}}Summary.new(
      id: record.id,
      name: record.name,
      status: record.status
    )
  end
end