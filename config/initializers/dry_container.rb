# frozen_string_literal: true

require "dry/container"
require "dry/auto_inject"

# ApplicationContainer - Central dependency injection container
# This container registers all repositories, commands, and queries
# Use Import[] to inject dependencies into classes
class ApplicationContainer
  extend Dry::Container::Mixin

  # Repositories namespace
  # Infrastructure layer - data access and persistence
  namespace :repositories do
    # Repositories will be registered here as we create them
    # Example: register(:user_repository) { Infrastructure::Persistence::Repositories::UserRepository.new }
  end

  # Commands namespace
  # Application layer - write operations (commands that change state)
  namespace :commands do
    # Commands will be registered here
    # Example: register(:users_authenticate) { Operations::Commands::Users::Authenticate.new }
  end

  # Queries namespace
  # Application layer - read operations (queries that fetch data)
  namespace :queries do
    # Queries will be registered here
    # Example: register(:users_find) { Operations::Queries::Users::Find.new }
  end
end

# Import[] allows automatic dependency injection
# Usage in classes:
#   include Import["repositories.user_repository"]
#   def call
#     user_repository.find(id)
#   end
Import = Dry::AutoInject(ApplicationContainer)
