# frozen_string_literal: true

# MagicLink model - Pure data mapper (Hanami-style)
#
# This model is intentionally thin:
# - NO scopes (query logic belongs in MagicLinkRepo)
# - NO business logic (belongs in Structs::MagicLink or Operations)
# - NO validations (handled by contracts)
# - NO callbacks
#
# Only contains:
# - Table mapping
# - Associations (for eager loading)
# - has_secure_token (Rails infrastructure for token generation)
#
# For magic link queries, see: MagicLinkRepo
# For magic link business logic, see: Structs::MagicLink
# For magic link operations, see: Operations::MagicLinks::*
#
class MagicLink < ApplicationRecord
  # Token generation infrastructure (required for secure tokens)
  has_secure_token :token

  # Associations (for eager loading in repos)
  belongs_to :user
end