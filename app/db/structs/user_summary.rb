# frozen_string_literal: true

module Structs
  # Lightweight User summary for collection operations
  #
  # Used by: all, where, search, admins, referees
  # Performance: Ruby Data class (7x faster than dry-struct)
  #
  # This struct contains minimal attributes needed for list views.
  # For full user details, use Structs::User via find/find_by.
  #
  # Example:
  #   summary = Structs::UserSummary.new(
  #     id: 1,
  #     email_address: "admin@ismf-ski.com",
  #     name: "Admin User",
  #     admin: true,
  #     role_name: "referee_manager",
  #     created_at: Time.current
  #   )
  #
  #   summary.display_name  # => "Admin User"
  #   summary.admin?        # => true
  #   summary.referee?      # => true (based on role_name)
  #
  UserSummary = Data.define(
    :id,
    :email_address,
    :name,
    :admin,
    :role_name,
    :created_at
  ) do
    # =========================================================================
    # Display methods
    # =========================================================================

    def display_name
      name.to_s.empty? ? email_address.split("@").first : name
    end

    # =========================================================================
    # Role predicates
    # =========================================================================

    def admin?
      admin == true
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

    # =========================================================================
    # Rails routing compatibility
    # =========================================================================

    # Returns the ID as a string for Rails URL helpers
    # This enables using Data.define structs directly with path helpers like:
    #   admin_user_path(user_summary)
    #   edit_admin_user_path(user_summary)
    #
    # Note: Data.define structs don't inherit from DB::Struct, so this must
    # be defined explicitly for each summary struct.
    def to_param
      id.to_s
    end
  end
end
