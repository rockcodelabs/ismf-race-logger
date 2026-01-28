# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module IsmfRaceLogger
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # =========================================================================
    # ZEITWERK CONFIGURATION (Hanami-hybrid architecture)
    # =========================================================================
    # Define the namespace modules first (required before push_dir)
    require_relative "../app/operations"
    require_relative "../app/web"
    
    # Load DB base classes first (these are used by structs/repos)
    require_relative "../app/db/struct"
    require_relative "../app/db/repo"
    require_relative "../app/db/structs"

    # Configure Zeitwerk to use custom root namespaces
    Rails.autoloaders.main.push_dir(Rails.root.join("app/operations"), namespace: ::Operations)
    Rails.autoloaders.main.push_dir(Rails.root.join("app/web"), namespace: ::Web)
    
    # Structs is a top-level namespace (not DB::Structs)
    Rails.autoloaders.main.push_dir(Rails.root.join("app/db/structs"), namespace: ::Structs)
    
    # Repos are top-level classes (UserRepo, not DB::Repos::UserRepo)
    Rails.autoloaders.main.push_dir(Rails.root.join("app/db/repos"), namespace: ::Object)
    
    # Broadcasters are top-level classes
    Rails.autoloaders.main.push_dir(Rails.root.join("app/broadcasters"), namespace: ::Object)
    
    # Ignore app/db base files since we load them manually above
    Rails.autoloaders.main.ignore(Rails.root.join("app/db.rb"))
    Rails.autoloaders.main.ignore(Rails.root.join("app/db/repo.rb"))
    Rails.autoloaders.main.ignore(Rails.root.join("app/db/struct.rb"))
    Rails.autoloaders.main.ignore(Rails.root.join("app/db/structs.rb"))
    Rails.autoloaders.main.ignore(Rails.root.join("app/db/package.yml"))

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
