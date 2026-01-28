# frozen_string_literal: true

# Role model - Pure data mapper (Hanami-style)
#
# This model is intentionally thin:
# - NO scopes (query logic belongs in RoleRepo)
# - NO business logic (belongs in Structs::Role or Operations)
# - NO validations (handled by contracts)
# - NO callbacks
#
# Only contains:
# - Table mapping
# - Associations (for eager loading)
#
# For role queries, see: RoleRepo
# For role business logic, see: Structs::Role
#
class Role < ApplicationRecord
  # Associations (for eager loading in repos)
  has_many :users, dependent: :nullify
end
