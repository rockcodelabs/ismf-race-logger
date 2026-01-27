# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview

ISMF Race Logger - Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

**Architecture**: Hanami-compatible layered architecture using Rails 8.1 + dry-rb (NO Hanami gem installed)

**🎉 REFACTOR STATUS**: Operations layer (formerly Application) established with passing tests!
- **Phase 1 Complete**: Domain (41 passing) + Operations (14 passing) layers ✅
- **Namespace Migration**: Application → Operations (avoiding Rails conflict)
- **Current Status**: 619 examples, 518 failures (101 passing - 16.3%)
- **Next Steps**: Fix MagicLink (28 failures) + Policies (400 failures) = Quick path to 85% passing
- See [REFACTOR-STATUS-2024.md](docs/REFACTOR-STATUS-2024.md) for complete status
- See [QUICK-WINS.md](docs/QUICK-WINS.md) for fixing remaining failures

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

### "watchman: not found" warning

The Tailwind container may show `sh: 1: watchman: not found`. This is **harmless and expected**. Watchman is an optional Facebook file-watching tool that Tailwind can use for optimization, but it's not available in default Debian repositories and is not required.

**TL;DR**: Ignore this warning. Tailwind CSS works perfectly fine without watchman - it has its own built-in file watching.

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

### Test Database Setup

```bash
docker compose exec -T -e RAILS_ENV=test app bin/rails db:test:prepare
```

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

## Project Structure (Hanami-Compatible Architecture)

```
ismf-race-logger/
├── app/
│   ├── domain/                          # Layer 1: Pure business logic
│   │   ├── entities/                    # Business objects (dry-struct)
│   │   ├── value_objects/               # Immutable data
│   │   ├── contracts/                   # Validation rules (dry-validation)
│   │   ├── services/                    # Pure calculations
│   │   └── types.rb                     # Custom dry-types
│   │
│   ├── operations/                      # Layer 2: Use cases
│   │   ├── commands/                    # Write operations
│   │   ├── queries/                     # Read operations
│   │   ├── contracts/                   # Input validation
│   │   └── container.rb                 # DI container
│   │
│   ├── infrastructure/                  # Layer 3: Adapters
│   │   ├── persistence/
│   │   │   ├── records/                 # ActiveRecord models (suffixed with "Record")
│   │   │   └── repositories/            # Data access layer
│   │   ├── jobs/                        # Background jobs
│   │   ├── mailers/                     # Email senders
│   │   └── storage/                     # File handling
│   │
│   └── web/                             # Layer 4: HTTP interface
│       ├── controllers/                 # Thin adapters
│       │   ├── concerns/
│       │   │   └── authentication.rb    # Rails 8.1 native auth
│       │   ├── admin/                   # Admin namespace
│       │   └── api/                     # API endpoints
│       ├── views/                       # HTML templates
│       └── components/                  # ViewComponent
│
├── config/
│   ├── routes.rb
│   ├── initializers/
│   │   └── dry_container.rb             # Dependency injection setup
│   └── environments/
├── spec/
│   ├── domain/                          # Fast unit tests (no DB)
│   ├── operations/                      # Integration tests
│   ├── infrastructure/                  # Repository tests
│   ├── web/                             # Request specs
│   └── support/
├── docs/
│   ├── architecture/                    # Architecture documentation
│   │   ├── README.md                    # Start here
│   │   ├── hanami-architecture-implementation-plan.md
│   │   ├── getting-started-hanami-architecture.md
│   │   ├── packwerk-boundaries.md
│   │   └── hanami-migration-guide.md
│   └── features/
├── package.yml                          # Packwerk root config
├── app/domain/package.yml               # Domain boundaries
├── app/operations/package.yml           # Operations boundaries
├── app/infrastructure/package.yml       # Infrastructure boundaries
├── app/web/package.yml                  # Web boundaries
└── docker-compose.yml
```

## Authentication

Rails 8.1 native authentication with:
- `has_secure_password` on User model
- Session-based auth with signed cookies
- `Current.user` for accessing logged-in user
- `require_authentication` before_action

### Key Files

- `app/controllers/concerns/authentication.rb` - Auth logic
- `app/controllers/sessions_controller.rb` - Login/logout
- `app/models/user.rb` - User with admin flag
- `app/models/session.rb` - Session storage

## Authorization

Admin access controlled by `user.admin?` flag.

```ruby
# In controllers
before_action :require_admin

def require_admin
  unless Current.user&.admin?
    redirect_to root_path, alert: "Not authorized"
  end
end
```

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

## Code Quality

### RuboCop - Style & Linting

RuboCop enforces consistent code style across the project. **Run before committing!**

```bash
# Quick check (recommended before commit)
bin/rubocop-check

# Auto-fix simple issues (trailing whitespace, newlines, spacing)
bin/rubocop-check --fix

# Check specific file/directory
bin/rubocop-check app/domain/

# GitHub Actions format (CI/CD)
docker compose exec -T app bin/rubocop -f github

# Manual fix in container
docker compose exec -T app bin/rubocop -A
```

#### Common Issues Auto-Fixed

- ✅ Trailing whitespace
- ✅ Missing final newlines
- ✅ Array bracket spacing (`[1, 2]` → `[ 1, 2 ]`)
- ✅ String literal quotes (prefer double quotes)
- ✅ Indentation and alignment

#### When to Run

1. **Before committing** - `bin/rubocop-check --fix`
2. **In CI/CD** - Automated via GitHub Actions
3. **After refactoring** - Ensure style consistency

### Test Coverage

All layers must have comprehensive tests:

```bash
# Run all tests (fast to slow)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain         # ~2ms/test
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/operations    # ~50ms/test
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web

# Current status: 619 examples, 0 failures ✅
```

### Architecture Boundaries

Packwerk enforces layer separation:

```bash
# Check boundaries (run before committing)
docker compose exec app bundle exec packwerk check

# Update dependencies after adding new references
docker compose exec app bundle exec packwerk update-todo
```

**Violations are not allowed in new code!**

## Code Style & Architecture Rules

### Layer Separation (ENFORCED by Packwerk)
- **Domain**: Pure Ruby + dry-rb only (NO Rails, NO ActiveRecord)
- **Operations**: Orchestrates domain + infrastructure via DI
- **Infrastructure**: ActiveRecord models suffixed with "Record" (e.g., `UserRecord`, `ReportRecord`)
- **Web**: Thin controllers, delegate to operations layer

### Dependencies Flow Downward
- Web → Operations → Domain
- Infrastructure → Domain (read-only for mapping)
- **Never upward** (Packwerk enforces this)

### Naming Conventions
- Entities: `Domain::Entities::Report` (dry-struct)
- Records: `Infrastructure::Persistence::Records::ReportRecord` (ActiveRecord)
- Repositories: `Infrastructure::Persistence::Repositories::ReportRepository`
- Commands: `Operations::Commands::Reports::Create`
- Controllers: `Web::Controllers::Api::ReportsController`

### Testing
- Domain: Fast unit tests (no DB) - `spec/domain/`
- Operations: Integration tests - `spec/operations/`
- Infrastructure: Repository tests - `spec/infrastructure/`
- Web: Request specs - `spec/web/`

### Technology Stack
- **dry-struct** - Domain entities
- **dry-validation** - Validation contracts
- **dry-monads** - Result objects
- **dry-auto_inject** - Dependency injection
- **packwerk** - Boundary enforcement
- **NO Hanami gem** (architecture is Hanami-compatible for future migration)

## Documentation

### Architecture (READ FIRST)
- `docs/architecture/README.md` - **Start here for architecture overview**
- `docs/architecture/getting-started-hanami-architecture.md` - How to work with layers
- `docs/architecture/hanami-architecture-implementation-plan.md` - Complete implementation guide
- `docs/architecture/packwerk-boundaries.md` - Boundary enforcement
- `docs/architecture/architecture-comparison.md` - Rails vs Hanami-compatible
- `docs/architecture/hanami-migration-guide.md` - Future: Creating Hanami 2 version

### Features & Implementation
- `docs/implementation-plan-rails-8.1.md` - Original Rails 8.1 setup
- `docs/architecture/report-incident-model.md` - Data model design
- `docs/features/fop-realtime-performance.md` - Real-time features

### AI Agents
- `.agents/` - AI agent instructions (rspec, console, etc.)

### Refactor Status
- `REFACTOR-COMPLETE.md` - User & Authentication refactor summary
- `.deprecated/` - Old Rails code (to be deleted after verification)

## Key Commands

```bash
# Check architecture boundaries (run before committing)
docker compose exec app bundle exec packwerk check

# Run tests by layer (fastest to slowest)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain         # ~2ms/test (NO DB)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/operations    # ~50ms/test
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure # ~50ms/test
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web           # ~100ms/test

# Run all tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# RuboCop - Code style checks (run before committing)
bin/rubocop-check              # Check all files
bin/rubocop-check --fix        # Auto-fix simple issues
docker compose exec -T app bin/rubocop -f github  # GitHub Actions format
docker compose exec -T app bin/rubocop -A         # Auto-correct in container

# Rails console (access DI container)
docker compose exec app bin/rails console
# Example: ApplicationContainer.resolve("commands.users.authenticate")
# Use Operations::Commands::Users::Authenticate.new

# Verify old code references are gone
grep -r "^User\." app/ --exclude-dir=infrastructure
grep -r "^Role\." app/ --exclude-dir=infrastructure
```