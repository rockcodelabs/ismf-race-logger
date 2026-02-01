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
      # ActiveModel::Naming provides model_name (class method and instance method)
      # ActiveModel::Conversion provides to_model, to_key, to_param, to_partial_path
      extend ActiveModel::Naming
      include ActiveModel::Conversion

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

      # Override: Rails checks persisted? to determine if object is saved
      # ActiveModel::Conversion's to_key and to_param depend on this
      def persisted?
        value.respond_to?(:id) && value.id.present?
      end

      # Override: Use struct's ID instead of class-based model_name for routing
      # ActiveModel::Naming gives us "web_parts_incidents" but we need "incidents"
      def model_name
        @model_name ||= begin
          # Extract model name from struct class
          # e.g., Structs::Incident -> Incident, Structs::IncidentSummary -> Incident
          klass_name = value.class.name.to_s.demodulize.sub(/Summary$/, '')
          
          # Try to find the actual model class for proper routing
          begin
            model_class = klass_name.constantize
            ActiveModel::Name.new(model_class)
          rescue NameError
            # Fallback: create a synthetic model name for routing
            ActiveModel::Name.new(self.class, nil, klass_name)
          end
        end
      end

      # Access Rails view helpers
      def helpers
        Web::Controllers::ApplicationController.helpers
      end
    end
  end
end
