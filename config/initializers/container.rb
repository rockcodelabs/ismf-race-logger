# frozen_string_literal: true

require "dry/container"
require "dry/auto_inject"

# AppContainer - Central dependency injection container for Hanami hybrid architecture
#
# This container registers all repositories and services as singletons.
# Use Import[] to inject dependencies into operations/use-cases.
#
# Example usage in operations:
#   class Operations::Users::Authenticate
#     include Import["repos.user"]
#
#     def call(email:, password:)
#       repos_user.authenticate(email, password)
#     end
#   end
#
# Example in tests (dependency substitution):
#   described_class.new(repos_user: mock_repo)
#
class AppContainer
  extend Dry::Container::Mixin

  # ============================================================================
  # REPOSITORIES
  # Repos are memoized (singleton per process) for efficiency
  # ============================================================================

  namespace :repos do
    # Fully implemented repos
    register :user, memoize: true do
      UserRepo.new
    end

    register :role, memoize: true do
      RoleRepo.new
    end

    register :session, memoize: true do
      SessionRepo.new
    end

    register :magic_link, memoize: true do
      MagicLinkRepo.new
    end
  end

  # ============================================================================
  # UTILITIES
  # ============================================================================

  register :logger do
    Rails.logger
  end
end

# Global import helper for dependency injection
# Usage: include Import["repos.user", "repos.report"]
Import = Dry::AutoInject(AppContainer)

# Backward compatibility alias (during migration from old ApplicationContainer)
ApplicationContainer = AppContainer
