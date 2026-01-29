# frozen_string_literal: true

require "dry-struct"
require "ismf_race_logger/types"

module DB
  # Base class for all structs (immutable data objects)
  #
  # Full structs use dry-struct for type safety and coercion.
  # Use for single records returned by find/find_by operations.
  #
  # Example:
  #   class Structs::User < DB::Struct
  #     attribute :id, Types::Integer
  #     attribute :email_address, Types::Email
  #     attribute :name, Types::String
  #     attribute :admin, Types::Bool.default(false)
  #   end
  #
  class Struct < Dry::Struct
    # Transform string keys to symbols for compatibility with ActiveRecord
    transform_keys(&:to_sym)

    # Alias Types module for convenience in subclasses
    Types = IsmfRaceLogger::Types

    # =========================================================================
    # Rails routing compatibility
    # =========================================================================

    # Returns the ID as a string for Rails URL helpers
    # This enables using structs directly with path helpers like:
    #   admin_user_path(user_struct)
    #   edit_admin_race_path(race_struct)
    def to_param
      id.to_s
    end
  end
end
