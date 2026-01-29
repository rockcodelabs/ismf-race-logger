# frozen_string_literal: true

require "dry/container"
require "dry/auto_inject"

# AppContainer - Central dependency injection container for Hanami hybrid architecture
#
# This container registers all repositories, parts, broadcasters, and services as singletons.
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

    register :competition, memoize: true do
      CompetitionRepo.new
    end

    register :race, memoize: true do
      RaceRepo.new
    end

    register :race_type, memoize: true do
      RaceTypeRepo.new
    end
  end

  # ============================================================================
  # PARTS
  # Parts factory for wrapping structs with presentation logic
  # ============================================================================

  namespace :parts do
    register :factory, memoize: true do
      Web::Parts::Factory.new
    end
  end

  # ============================================================================
  # BROADCASTERS
  # Turbo Stream broadcasters for real-time updates
  # ============================================================================

  namespace :broadcasters do
    register :incident, memoize: true do
      IncidentBroadcaster.new
    end

    register :user, memoize: true do
      UserBroadcaster.new
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
