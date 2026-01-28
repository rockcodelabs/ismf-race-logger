# frozen_string_literal: true

# Session model - Pure data mapper (Hanami-style)
#
# This model is intentionally thin:
# - NO scopes (query logic belongs in SessionRepo)
# - NO business logic (belongs in Structs::Session or Operations)
# - NO validations (handled by contracts)
# - NO callbacks
#
# Only contains:
# - Table mapping
# - Associations (for eager loading)
#
# For session queries, see: SessionRepo
# For session operations, see: Operations::Sessions::*
#
class Session < ApplicationRecord
  # Associations (for eager loading in repos)
  belongs_to :user
end