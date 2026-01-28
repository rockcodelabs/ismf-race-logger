# frozen_string_literal: true

module Structs
  # Immutable representation of a %{resource_name} record
  #
  # Used for single record operations (find, find!, find_by).
  # For collections, use %{resource_name}Summary instead.
  #
  # @example
  #   struct = Structs::%{resource_name}.new(
  #     id: 1,
  #     name: "Example",
  #     created_at: Time.current,
  #     updated_at: Time.current
  #   )
  #
  class %{resource_name} < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Add resource-specific attributes here:
    # attribute :name, Types::String
    # attribute :email, Types::Email
    # attribute :status, Types::String
    # attribute :count, Types::Integer.optional.default(0)
    # attribute :active, Types::Bool.optional.default(false)
    # attribute :metadata, Types::Hash.optional.default({}.freeze)

    # Domain methods (NO presentation logic)
    #
    # Good: business rules, state checks, derived values
    # Bad: formatting, HTML, display strings

    # @example Domain method
    # def active?
    #   status == "active"
    # end

    # @example Derived value
    # def display_name
    #   name.presence || email.split("@").first
    # end
  end
end