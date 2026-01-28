# frozen_string_literal: true

module Web
  module Parts
    # Base class for all view parts
    #
    # Parts wrap domain structs and add view-specific presentation logic.
    # This keeps structs pure and templates simple.
    #
    # Example:
    #   part = Web::Parts::User.new(user_struct)
    #   part.display_name      # Presentation logic
    #   part.email_address     # Delegated to struct
    #
    class Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      # Delegate missing methods to the wrapped value
      def method_missing(method, *args, &block)
        if value.respond_to?(method)
          value.public_send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        value.respond_to?(method) || super
      end

      # For use in dom_id and other Rails helpers
      def to_model
        value
      end

      def to_s
        value.to_s
      end

      # Access Rails view helpers
      def helpers
        ApplicationController.helpers
      end
    end
  end
end
