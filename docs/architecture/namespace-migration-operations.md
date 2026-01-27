# Namespace Migration: Application → Operations

**Status**: ✅ Complete  
**Date**: 2024  
**Migration Type**: Namespace Refactoring

## Overview

The `Application` namespace has been renamed to `Operations` to avoid conflicts with Rails' `IsmfRaceLogger::Application` class and to better align with dry-rb ecosystem conventions.

## Motivation

### Problems with `Application` Namespace

1. **Namespace Conflict**: Rails defines `IsmfRaceLogger::Application` as the main application class, which created Zeitwerk autoloading conflicts with our `Application` module for the use cases layer.

2. **Semantic Clarity**: "Application" is overloaded in Rails context - it refers to both the Rails app itself and our business logic layer.

3. **Ecosystem Alignment**: The dry-rb ecosystem commonly uses "Operations" for orchestration logic (commands/queries).

### Benefits of `Operations` Namespace

- ✅ No conflict with Rails naming
- ✅ Clear semantic meaning (operational logic)
- ✅ Aligns with dry-rb community conventions
- ✅ Distinguishes business operations from Rails framework

## Architecture Layers (Updated)

```
┌─────────────────────────────────────────┐
│            Web Layer                     │
│     (HTTP Interface, Controllers)        │
└─────────────────┬───────────────────────┘
                  │ depends on
                  ▼
┌─────────────────────────────────────────┐
│        Operations Layer                  │
│    (Commands, Queries, Use Cases)        │
└─────────────────┬───────────────────────┘
                  │ depends on
    ┌─────────────┴─────────────┐
    ▼                           ▼
┌──────────────┐        ┌──────────────────┐
│    Domain    │        │  Infrastructure  │
│   (Entities, │        │  (Repositories,  │
│   Contracts) │        │   Records, Jobs) │
└──────────────┘        └──────────────────┘
```

## Changes Made

### 1. Directory Structure

**Before:**
```
app/
├── application/
│   ├── commands/
│   │   └── users/
│   │       └── authenticate.rb
│   ├── queries/
│   └── package.yml
└── application.rb
```

**After:**
```
app/
├── operations/
│   ├── commands/
│   │   └── users/
│   │       └── authenticate.rb
│   ├── queries/
│   └── package.yml
└── operations.rb
```

### 2. Module Definitions

**Before:**
```ruby
# app/application.rb
module Application
end

# app/application/commands/users/authenticate.rb
module Application
  module Commands
    module Users
      class Authenticate
        # ...
      end
    end
  end
end
```

**After:**
```ruby
# app/operations.rb
module Operations
end

# app/operations/commands/users/authenticate.rb
module Operations
  module Commands
    module Users
      class Authenticate
        # ...
      end
    end
  end
end
```

### 3. Test Directory Structure

**Before:**
```
spec/
├── application/
│   ├── commands/
│   └── queries/
```

**After:**
```
spec/
├── operations/
│   ├── commands/
│   └── queries/
```

### 4. Packwerk Configuration

**Before:**
```yaml
# app/application/package.yml
enforce_dependencies: true
dependencies:
  - app/domain

# app/web/package.yml
dependencies:
  - app/application
  - app/domain
```

**After:**
```yaml
# app/operations/package.yml
enforce_dependencies: true
dependencies:
  - app/domain
  - app/infrastructure

# app/web/package.yml
dependencies:
  - app/operations
  - app/domain
  - app/infrastructure
```

### 5. Zeitwerk Configuration

**Before:**
```ruby
# config/application.rb
require_relative "../app/application"  # Causes conflict!
module ::Application; end  # Manual workaround
Rails.autoloaders.main.push_dir(
  Rails.root.join("app/application"), 
  namespace: ::Application
)
```

**After:**
```ruby
# config/application.rb
require_relative "../app/operations"  # No conflict
Rails.autoloaders.main.push_dir(
  Rails.root.join("app/operations"), 
  namespace: ::Operations
)
```

### 6. Controller References

**Before:**
```ruby
# app/web/controllers/sessions_controller.rb
def authenticate_user_command
  @authenticate_user_command ||= Application::Commands::Users::Authenticate.new
end
```

**After:**
```ruby
# app/web/controllers/sessions_controller.rb
def authenticate_user_command
  @authenticate_user_command ||= Operations::Commands::Users::Authenticate.new
end
```

### 7. DI Container Registration

**Before:**
```ruby
# config/initializers/dry_container.rb
ApplicationContainer.register("commands.users.authenticate") do
  Application::Commands::Users::Authenticate.new
end
```

**After:**
```ruby
# config/initializers/dry_container.rb
ApplicationContainer.register("commands.users.authenticate") do
  Operations::Commands::Users::Authenticate.new
end
```

### 8. Test Specs

**Before:**
```ruby
# spec/application/commands/users/authenticate_spec.rb
RSpec.describe Application::Commands::Users::Authenticate do
  # ...
end
```

**After:**
```ruby
# spec/operations/commands/users/authenticate_spec.rb
RSpec.describe Operations::Commands::Users::Authenticate do
  # ...
end
```

## Migration Checklist

All items completed:

- [x] Rename `app/application.rb` → `app/operations.rb`
- [x] Move `app/application/` → `app/operations/`
- [x] Update module definitions in all files
- [x] Update Zeitwerk configuration in `config/application.rb`
- [x] Update Packwerk package.yml files
- [x] Update DI container registration examples
- [x] Move `spec/application/` → `spec/operations/`
- [x] Update all spec file references
- [x] Update controller references
- [x] Update CLAUDE.md documentation
- [x] Verify Packwerk boundaries
- [x] Run tests to verify changes

## Verification

### Packwerk Check
```bash
docker compose exec app bundle exec packwerk check
# Should pass with only expected violations (infrastructure dependencies)
```

### Test Suite
```bash
# Operations layer tests (should all pass)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/operations
# 14 examples, 0 failures ✅

# Domain layer tests (should all pass)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain
# 41 examples, 0 failures ✅
```

## Naming Conventions

### Operations Layer Components

| Component Type | Naming Pattern | Example |
|----------------|----------------|---------|
| Command | `Operations::Commands::{Context}::{Action}` | `Operations::Commands::Users::Authenticate` |
| Query | `Operations::Queries::{Context}::{Action}` | `Operations::Queries::Users::Find` |
| Spec | `spec/operations/{type}/{context}/{action}_spec.rb` | `spec/operations/commands/users/authenticate_spec.rb` |

### Dependencies

```
Operations Layer can depend on:
  ✅ Domain (entities, contracts, types)
  ✅ Infrastructure (repositories, records)
  
Operations Layer CANNOT depend on:
  ❌ Web (controllers, views)
```

## Code Examples

### Creating a New Command

```ruby
# app/operations/commands/reports/create.rb
module Operations
  module Commands
    module Reports
      class Create
        include Dry::Monads[:result]
        
        def initialize(report_repository: Infrastructure::Persistence::Repositories::ReportRepository.new)
          @report_repository = report_repository
        end
        
        def call(params)
          # Validate with domain contract
          contract = Domain::Contracts::ReportContract.new
          result = contract.call(params)
          
          return Failure([:validation_failed, result.errors.to_h]) if result.failure?
          
          # Create via repository
          report = @report_repository.create(result.to_h)
          
          Success(report)
        end
      end
    end
  end
end
```

### Creating a New Query

```ruby
# app/operations/queries/reports/list.rb
module Operations
  module Queries
    module Reports
      class List
        include Dry::Monads[:result]
        
        def initialize(report_repository: Infrastructure::Persistence::Repositories::ReportRepository.new)
          @report_repository = report_repository
        end
        
        def call(filters = {})
          reports = @report_repository.all(filters)
          Success(reports)
        end
      end
    end
  end
end
```

### Using in Controllers

```ruby
# app/web/controllers/reports_controller.rb
module Web
  module Controllers
    class ReportsController < ApplicationController
      def create
        result = create_command.call(report_params)
        
        result.either(
          ->(report) { redirect_to report_path(report.id) },
          ->(error) { render :new, alert: error }
        )
      end
      
      private
      
      def create_command
        @create_command ||= Operations::Commands::Reports::Create.new
      end
    end
  end
end
```

## Breaking Changes

**None for end users** - This is an internal architecture change that doesn't affect:
- Database schema
- API endpoints
- User-facing functionality
- Environment configuration

**For developers:**
- Update any references from `Application::` to `Operations::`
- Update test paths from `spec/application/` to `spec/operations/`
- Update DI container registrations if manually configured

## Related Documentation

- [Hanami Architecture Implementation Plan](./hanami-architecture-implementation-plan.md)
- [Getting Started with Hanami Architecture](./getting-started-hanami-architecture.md)
- [Packwerk Boundaries](./packwerk-boundaries.md)

## Future Considerations

1. **Command/Query Separation**: The Operations layer naturally separates writes (Commands) from reads (Queries), supporting CQRS patterns if needed.

2. **DI Container**: Consider registering all operations in `ApplicationContainer` for better testability and dependency injection.

3. **Operation Chaining**: Complex workflows can compose multiple operations using dry-monads' `Do` notation.

4. **Hanami Migration**: When migrating to Hanami 2, this Operations layer maps cleanly to Hanami's action/operation patterns.

## Questions?

For questions about this migration or the Operations layer architecture, see:
- `docs/architecture/README.md` - Architecture overview
- `docs/architecture/getting-started-hanami-architecture.md` - Development guide
- `CLAUDE.md` - Project guidelines