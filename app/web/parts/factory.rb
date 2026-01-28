# frozen_string_literal: true

module Web
  module Parts
    # Factory for wrapping structs in their corresponding parts
    #
    # Automatically resolves: Structs::Incident → Web::Parts::Incident
    #
    # Example:
    #   factory = Web::Parts::Factory.new
    #   part = factory.wrap(incident_struct)  # => Web::Parts::Incident
    #   parts = factory.wrap_many(incidents)  # => [Web::Parts::Incident, ...]
    #
    class Factory
      # Wrap a single struct in its corresponding part
      def wrap(struct)
        return nil if struct.nil?

        part_class_for(struct).new(struct)
      end

      # Wrap a collection of structs
      def wrap_many(structs)
        structs.map { |s| wrap(s) }
      end

      private

      def part_class_for(struct)
        # Structs::Incident → "Incident" → Web::Parts::Incident
        # Structs::UserSummary → "UserSummary" → Web::Parts::UserSummary (or fallback to User)
        part_name = struct.class.name.sub("Structs::", "")
        "Web::Parts::#{part_name}".constantize
      rescue NameError
        # Try base name for summaries (Structs::UserSummary → Web::Parts::User)
        base_name = part_name.sub(/Summary$/, "")
        "Web::Parts::#{base_name}".constantize
      rescue NameError
        # Fall back to base part if no specific part exists
        Web::Parts::Base
      end
    end
  end
end
