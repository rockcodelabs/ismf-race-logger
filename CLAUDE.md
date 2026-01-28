# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview

ISMF Race Logger - Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

**Architecture**: Hanami-compatible layered architecture using Rails 8.1 + dry-rb (NO Hanami gem installed)

## Tech Stack

- **Framework**: Ruby on Rails 8.1.2
- **Ruby**: 3.4.8
- **Database**: PostgreSQL 16
- **Background Jobs**: Solid Queue (database-backed)
- **Caching**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **CSS**: TailwindCSS v4
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Testing**: RSpec
- **Containerization**: Docker Compose

## Development Environment

### Starting the App

```bash
# Build containers
docker compose build

# Setup database
docker compose run -T --rm app bin/rails db:create db:migrate db:seed

# Start all services
docker compose up
```

App runs at: http://localhost:3005

### Services

| Service    | Container       | Port |
|------------|-----------------|------|
| Rails App  | ismf-app        | 3005 |
| PostgreSQL | ismf-postgres   | 5433 |
| Tailwind   | ismf-tailwind   | -    |

## Troubleshooting

### "Server already running" error

If you see `A server is already running (pid: X, file: /rails/tmp/pids/server.pid)`:

```bash
# The dev-entrypoint script should handle this automatically,
# but if needed, manually remove the PID file:
docker compose exec app rm -f tmp/pids/server.pid

# Or rebuild containers:
docker compose down
docker compose up --build
```

## ⚠️ CRITICAL: Running Tests

**ALWAYS run tests with explicit `RAILS_ENV=test`:**

```bash
# Run all tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Run specific file
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb

# Run specific test (line number)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb:25

# With documentation format
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format documentation
```

**Why?** The Docker container defaults to development environment. Without `-e RAILS_ENV=test`, tests will fail with 403 Forbidden due to host authorization.

## Rails Console

```bash
# Development console
docker compose exec app bin/rails console

# Run one-off commands
docker compose exec -T app bin/rails runner "puts User.count"
```

## Common Commands

```bash
# Migrations
docker compose exec -T app bin/rails db:migrate

# Seed data
docker compose exec -T app bin/rails db:seed

# Reset database
docker compose exec -T app bin/rails db:drop db:create db:migrate db:seed

# View logs
docker compose logs -f app

# Rebuild containers (after Dockerfile changes)
docker compose build --no-cache

# Stop everything
docker compose down

# Clean restart (removes stale PID files)
docker compose down
docker compose up --build
```

## Project Structure (Hanami-Hybrid Architecture)

```
ismf-race-logger/
├── app/
│   ├── db/                              # Layer 1: Persistence
│   │   ├── repo.rb                      # Base repository class
│   │   ├── struct.rb                    # Base struct class
│   │   ├── repos/                       # Data access layer
│   │   │   ├── user_repo.rb
│   │   │   ├── role_repo.rb
│   │   │   ├── session_repo.rb
│   │   │   └── magic_link_repo.rb
│   │   └── structs/                     # Immutable data objects
│   │       ├── user.rb                  # Full struct (dry-struct) for single records
│   │       └── user_summary.rb          # Summary struct (Data) for collections
│   │
│   ├── models/                          # Thin ActiveRecord models
│   │   ├── user.rb
│   │   ├── role.rb
│   │   ├── session.rb
│   │   ├── magic_link.rb
│   │   └── current.rb                   # Rails 8.1 current attributes
│   │
│   ├── operations/                      # Layer 2: Use cases
│   │   ├── contracts/                   # Input validation (dry-validation)
│   │   │   └── authenticate_user.rb
│   │   └── users/                       # User operations
│   │       ├── authenticate.rb          # Command
│   │       ├── find.rb                  # Query
│   │       └── list.rb                  # Query
│   │
│   ├── web/                             # Layer 3: HTTP interface
│   │   ├── controllers/                 # Thin controllers
│   │   │   ├── concerns/
│   │   │   │   └── authentication.rb    # Rails 8.1 native auth
│   │   │   ├── admin/                   # Admin namespace
│   │   │   └── sessions_controller.rb
│   │   ├── parts/                       # Presentation decorators (Hanami-style)
│   │   │   ├── base.rb                  # Base part class
│   │   │   ├── factory.rb               # Auto-wraps structs → parts
│   │   │   └── user.rb                  # User presentation logic
│   │   └── templates/                   # HTML templates (ERB)
│   │       ├── layouts/
│   │       │   ├── application.html.erb
│   │       │   ├── application.turbo_native.html.erb
│   │       │   └── admin.html.erb
│   │       ├── sessions/
│   │       ├── home/
│   │       ├── admin/
│   │       └── shared/
│   │
│   ├── broadcasters/                    # Real-time Turbo Stream broadcasts
│   │   ├── base_broadcaster.rb
│   │   └── incident_broadcaster.rb
│   │
│   └── javascript/
│       └── controllers/                 # Stimulus controllers
│           ├── flash_controller.js
│           └── presence_controller.js
│
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   └── container.rb                 # AppContainer (dry-container + auto_inject)
│   └── environments/
├── lib/
│   └── ismf_race_logger/
│       └── types.rb                     # Shared dry-types
├── spec/
│   ├── db/                              # Repo & struct tests
│   ├── models/                          # Model tests
│   ├── operations/                      # Operation tests
│   └── web/                             # Request specs
├── docs/
│   └── architecture/
│       ├── hanami-hybrid-architecture.md  # DB + Operations layers
│       └── web-layer.md                   # Web layer architecture
├── package.yml                          # Packwerk root config
├── app/db/package.yml                   # DB layer boundaries
├── app/operations/package.yml           # Operations boundaries
├── app/web/package.yml                  # Web boundaries
└── docker-compose.yml
```

## Authentication

Rails 8.1 native authentication with:
- `has_secure_password` on User model
- Session-based auth with signed cookies
- `Current.user` for accessing logged-in user
- `require_authentication` before_action

## Authorization

We use Pundit for authorization.

## Default Users (Development)

| Role            | Email                      | Password    | System Role      |
|-----------------|----------------------------|-------------|------------------|
| Admin           | admin@ismf-ski.com         | password123 | referee_manager  |
| Admin           | dariusz.finster@gmail.com  | test123     | referee_manager  |
| Referee         | referee@ismf-ski.com       | password123 | national_referee |
| VAR Operator    | var@ismf-ski.com           | password123 | var_operator     |
| User            | user@example.com           | password123 | (none)           |

## ISMF Brand Colors

| Color | Hex       | CSS Variable        |
|-------|-----------|---------------------|
| Navy  | #1a1a2e   | --color-ismf-navy   |
| Red   | #e94560   | --color-ismf-red    |
| Blue  | #0f3460   | --color-ismf-blue   |
| Gray  | #6b7280   | --color-ismf-gray   |

## Code Quality & Architecture Enforcement

### RuboCop - Style & Architecture Linting

RuboCop enforces both code style AND architectural patterns. **Run before committing!**

```bash
# Quick check (recommended before commit)
docker compose exec -T app bundle exec rubocop

# Auto-fix simple issues (trailing whitespace, newlines, spacing, frozen string literals)
docker compose exec -T app bundle exec rubocop -A

#### Architectural Rules Enforced

- ✅ **Frozen string literals** - All files must have `# frozen_string_literal: true`
- ✅ **Documentation** - Repos, operations, and lib code must have top-level docs
- ✅ **Complexity limits** - Methods ≤25 lines, ABC ≤25, cyclomatic ≤10
- ✅ **Class length** - Operations focused, repos can be longer (≤250 lines)
- ✅ **Collection performance** - Use Ruby `Data` classes for summaries, dry-struct for single records

#### Common Issues Auto-Fixed

- ✅ Frozen string literal comments
- ✅ Trailing whitespace
- ✅ Missing final newlines
- ✅ Array bracket spacing (`[ 1, 2 ]`)
- ✅ Indentation and alignment

#### When to Run

1. **Before committing** - `docker compose exec -T app bundle exec rubocop -A`
2. **In CI/CD** - Automated via GitHub Actions
3. **After refactoring** - Ensure consistency

### Packwerk - Architecture Boundaries

Packwerk enforces layer separation and prevents circular dependencies:

```bash
# Check boundaries (run before committing)
docker compose exec app bundle exec packwerk check

# Update dependencies after adding new references (not recommended for new code)
docker compose exec app bundle exec packwerk update-todo
```

#### Package Dependencies (Enforced)

```
Root (.)
├── depends on: app/db, app/operations, app/web
│
app/db
├── depends on: . (for AR models)
│
app/operations
├── depends on: . (for Import), app/db (for repos/structs)
│
app/web
├── depends on: . (for models), app/db (optional), app/operations
```

**❌ Violations are NOT allowed in new code!**
**✅ All boundaries must be clean before merging**

## Code Style & Architecture Rules

### Layer Separation (ENFORCED by Packwerk + RuboCop)

1. **app/models/** - Thin ActiveRecord models (persistence only)
   - Associations, validations, scopes
   - NO business logic
   - NO direct controller access to complex queries

2. **app/db/repos/** - Repository pattern (public persistence API)
   - All DB queries go through repos
   - Returns structs (immutable), not AR models
   - Custom query methods (e.g., `find_by_email`, `list_with_roles`)

3. **app/db/structs/** - Immutable data objects
   - **Full structs**: dry-struct for single records (type-safe)
   - **Summary structs**: Ruby `Data` for collections (performance)
   - NO business logic, pure data

4. **app/operations/** - Use cases and business workflows
   - Orchestrates repos via dependency injection
   - Returns dry-monads results (`Success(data)` or `Failure(error)`)
   - Input validation with dry-validation contracts

5. **app/web/controllers/** - Thin HTTP adapters
   - Call operations for business logic
   - Use Parts Factory to wrap structs for templates
   - Handle HTTP responses (redirects, flash messages)
   - Pattern matching on operation results

6. **app/web/parts/** - Presentation decorators (Hanami-style)
   - Wrap structs with view-specific logic
   - Keep structs pure (domain only), templates simple
   - Factory auto-resolves: `Structs::User` → `Web::Parts::User`
   - Testable in isolation

7. **app/web/templates/** - ERB templates
   - Use Parts for all presentation logic (no inline conditionals)
   - Rails variants for Turbo Native (`.turbo_native.html.erb`)
   - Co-located with web layer

8. **app/broadcasters/** - Real-time Turbo Stream broadcasts
   - Wrap structs in Parts before rendering partials
   - Registered in DI container
   - Separate from business logic (Operations)

### Dependencies Flow (Enforced)
```
app/web → app/operations → app/db → app/models
           ↓
      (lib/types)
```

**Never upward!** Packwerk prevents reverse dependencies.

### Naming Conventions
- Models: `User`, `Role` (thin AR models in app/models/)
- Repos: `UserRepo`, `RoleRepo` (in app/db/repos/)
- Structs: `Structs::User`, `Structs::UserSummary` (in app/db/structs/)
- Operations: `Operations::Users::Authenticate`, `Operations::Users::List`
- Contracts: `Operations::Contracts::AuthenticateUser`
- Controllers: `Web::Controllers::SessionsController`
- Parts: `Web::Parts::User`, `Web::Parts::Incident` (in app/web/parts/)
- Broadcasters: `IncidentBroadcaster`, `UserBroadcaster` (in app/broadcasters/)

### Web Layer Patterns

#### Parts (Presentation Decorators)
```ruby
# Parts wrap structs for view-specific logic
part = Web::Parts::User.new(user_struct)
part.avatar_initials  # => "J" (presentation logic)
part.email_address    # => delegates to struct

# Use factory for auto-resolution
factory = AppContainer["parts.factory"]
part = factory.wrap(user_struct)  # => Web::Parts::User
parts = factory.wrap_many(users)  # => [Web::Parts::User, ...]
```

#### Broadcasters (Real-Time)
```ruby
# Broadcasters handle Turbo Stream delivery
broadcaster = AppContainer["broadcasters.incident"]
broadcaster.created(incident_struct)   # Broadcasts to all subscribers
broadcaster.updated(incident_struct)
broadcaster.deleted(incident_struct)
```

#### Turbo Native Support
```ruby
# Automatic variant detection in ApplicationController
before_action :set_variant

def set_variant
  request.variant = :turbo_native if turbo_native_app?
end

# Rails auto-resolves templates:
# - Web: index.html.erb
# - Native: index.turbo_native.html.erb (falls back to index.html.erb)
```

### Performance Pattern
- **Single record**: Use dry-struct (e.g., `Structs::User`)
  - Type-safe with `attribute :email, Types::Email`
  - Slower instantiation (~2x AR model)
- **Collections**: Use Ruby `Data` class (e.g., `Structs::UserSummary`)
  - Much faster (~10x faster than dry-struct)
  - Minimal fields needed for lists

### Testing Strategy
- **spec/db/**: Repo & struct tests (use DB)
- **spec/models/**: AR model tests (associations, validations)
- **spec/operations/**: Operation tests (integration, use repos)
- **spec/web/**: Controller request specs (full stack)

### Technology Stack
- **dry-struct** - Type-safe structs for single records
- **Ruby Data** - Fast structs for collections
- **dry-validation** - Input validation contracts
- **dry-monads** - Result objects
- **dry-auto_inject** - Dependency injection
- **packwerk** - Boundary enforcement
- **rubocop-rails-omakase** - Code style + custom architectural rules
- **Turbo + Hotwire** - Real-time updates, SPA-like navigation
- **Turbo Native** - iOS/Android native app support
- **Stimulus** - Lightweight JavaScript controllers
- **Solid Cable** - Database-backed WebSockets (Action Cable)

### Container Keys (DI)
```ruby
# Repos
AppContainer["repos.user"]           # => UserRepo
AppContainer["repos.incident"]       # => IncidentRepo

# Parts
AppContainer["parts.factory"]        # => Web::Parts::Factory

# Broadcasters
AppContainer["broadcasters.incident"] # => IncidentBroadcaster
AppContainer["broadcasters.user"]     # => UserBroadcaster
```

## Documentation

### Architecture Guides
- `docs/architecture/hanami-hybrid-architecture.md` - DB layer, Operations, Structs, Repos
- `docs/architecture/web-layer.md` - Controllers, Parts, Templates, Broadcasters, Turbo Native

# Rails console (with dependency injection)
docker compose exec app bin/rails console
# Example usage:
#   user_repo = AppContainer["repos.user"]
#   user = user_repo.find(1)
#   auth = Operations::Users::Authenticate.new
#   result = auth.call(email: "test@example.com", password: "password")