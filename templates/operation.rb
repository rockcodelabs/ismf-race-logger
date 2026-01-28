# frozen_string_literal: true

module Operations
  module {{Resources}}
    # {{Description}}
    class {{Action}}
      include Dry::Monads[:result]
      include Import["repos.{{resource}}"]

      # @param params [Hash] Input parameters
      # @return [Dry::Monads::Result] Success(struct) or Failure(errors)
      def call(params)
        contract = Operations::Contracts::{{Action}}{{Resource}}.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        {{resource}} = repos_{{resource}}.create(validation.to_h)
        return Failure(:creation_failed) unless {{resource}}

        Success({{resource}})
      end
    end
  end
end

# Usage:
#   result = Operations::{{Resources}}::{{Action}}.new.call(params)
#   case result
#   in Success({{resource}})
#     # handle success
#   in Failure(errors)
#     # handle failure
#   end
#
# Placeholders:
#   {{Resources}}   - Plural resource name (e.g., Incidents)
#   {{Resource}}    - Singular resource name (e.g., Incident)
#   {{resource}}    - Lowercase singular (e.g., incident)
#   {{Action}}      - Operation action (e.g., Create, Update, Delete)
#   {{Description}} - Brief description of what this operation does