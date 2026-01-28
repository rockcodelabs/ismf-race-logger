# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for User in views
    #
    # Wraps Structs::User and Structs::UserSummary with view-specific methods.
    # Keeps structs pure (domain only) and templates simple (no inline logic).
    #
    # Example:
    #   part = Web::Parts::User.new(user_struct)
    #   part.avatar_initials        # => "J"
    #   part.role_badge             # => { class: "badge-danger", label: "Admin" }
    #   part.email_address          # Delegated to struct
    #
    class User < Base
      # Single letter for avatar circle
      def avatar_initials
        display_name.chars.first.upcase
      end

      # Badge configuration for role display
      def role_badge
        if value.admin?
          { class: "badge-danger", label: "Admin" }
        elsif value.referee?
          { class: "badge-warning", label: "Referee" }
        elsif value.var_operator?
          { class: "badge-info", label: "VAR Operator" }
        else
          { class: "badge-secondary", label: "User" }
        end
      end

      # Human-readable role name
      def role_display
        return "Admin" if value.admin?
        return nil unless value.role_name

        value.role_name.titleize.gsub("_", " ")
      end

      # Formatted creation date
      def created_at_formatted
        value.created_at.strftime("%b %d, %Y")
      end

      # Formatted creation date with time
      def created_at_full
        value.created_at.strftime("%B %d, %Y at %I:%M %p")
      end

      # DOM ID for Turbo Stream targeting
      def dom_id
        "user_#{value.id}"
      end

      # CSS classes for the avatar background based on role
      def avatar_bg_class
        if value.admin?
          "bg-ismf-red"
        elsif value.referee?
          "bg-ismf-blue"
        else
          "bg-ismf-gray"
        end
      end
    end
  end
end
