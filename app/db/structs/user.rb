# frozen_string_literal: true

module Structs
  # Full User struct for single record operations
  #
  # Used by: find, find!, find_by, authenticate, create, update
  # Performance: dry-struct with full type validation and coercion
  #
  # Example:
  #   user = Structs::User.new(
  #     id: 1,
  #     email_address: "admin@ismf-ski.com",
  #     name: "Admin User",
  #     admin: true,
  #     role_name: "referee_manager"
  #   )
  #
  #   user.admin?          # => true
  #   user.display_name    # => "Admin User"
  #   user.can_officialize_incident? # => true
  #
  class User < DB::Struct
    # Required attributes
    attribute :id, Types::Integer
    attribute :email_address, Types::Email
    attribute :name, Types::String
    attribute :admin, Types::Bool.default(false)
    attribute :created_at, Types::FlexibleDateTime
    attribute :updated_at, Types::FlexibleDateTime

    # Optional attributes
    attribute? :role_name, Types::RoleName.optional

    # =========================================================================
    # Display methods
    # =========================================================================

    def display_name
      name.presence || email_address.split("@").first
    end

    # =========================================================================
    # Role predicates
    # =========================================================================

    def admin?
      admin
    end

    def var_operator?
      role_name == "var_operator"
    end

    def national_referee?
      role_name == "national_referee"
    end

    def international_referee?
      role_name == "international_referee"
    end

    def jury_president?
      role_name == "jury_president"
    end

    def referee_manager?
      role_name == "referee_manager"
    end

    def broadcast_viewer?
      role_name == "broadcast_viewer"
    end

    def referee?
      national_referee? || international_referee?
    end

    def has_role?(role_name_to_check)
      role_name == role_name_to_check.to_s
    end

    # =========================================================================
    # Authorization helpers
    # =========================================================================

    def can_officialize_incident?
      admin? || referee? || referee_manager?
    end

    def can_decide_incident?
      admin? || referee_manager? || international_referee?
    end

    def can_merge_incidents?
      admin? || referee_manager?
    end

    def can_manage_users?
      admin?
    end
  end
end