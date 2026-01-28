# frozen_string_literal: true

# User model - Pure data mapper (Hanami-style)
#
# This model is intentionally thin:
# - NO scopes (query logic belongs in UserRepo)
# - NO business logic (belongs in Structs::User or Operations)
# - NO validations (handled by contracts in operations)
# - NO callbacks
#
# Only contains:
# - Table mapping
# - Associations (for eager loading)
# - has_secure_password (Rails infrastructure for password hashing)
#
# For user queries, see: UserRepo
# For user business logic, see: Structs::User
# For user operations, see: Operations::Users::*
#
class User < ApplicationRecord
  # Password hashing infrastructure (required for authentication)
  has_secure_password

  # Associations (for eager loading in repos)
  belongs_to :role, optional: true
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
end