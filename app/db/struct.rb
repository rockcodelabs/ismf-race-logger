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

    # =========================================================================
    # Pundit authorization compatibility
    # =========================================================================

    # Returns the ActiveRecord model class for Pundit authorization
    # Pundit calls this method to determine which policy to use
    #
    # This method dynamically converts struct class names to their corresponding
    # ActiveRecord model classes:
    #   Structs::User -> User
    #   Structs::RaceTypeLocationTemplate -> RaceTypeLocationTemplate
    #   Structs::Competition -> Competition
    #
    # @return [Class] The ActiveRecord model class
    # @raise [NameError] If the corresponding model class doesn't exist
    def to_model
      model_class_name = self.class.name.sub(/^Structs::/, '')
      model_class_name.constantize
    rescue NameError => e
      raise NameError, "Cannot find model class for struct #{self.class.name}. " \
                       "Expected to find #{model_class_name}. Original error: #{e.message}"
    end

    # Returns the model name for Pundit policy lookup
    # Delegates to the corresponding ActiveRecord model
    # @return [ActiveModel::Name]
    def model_name
      to_model.model_name
    end
  end
end
