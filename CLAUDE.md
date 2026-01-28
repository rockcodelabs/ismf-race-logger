# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview

ISMF Race Logger - Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

**Architecture**: Hanami-Hybrid (Rails 8.1 + dry-rb) — See `docs/ARCHITECTURE.md` for full details.

---

## Quick Commands

### Tests (CRITICAL: Always use RAILS_ENV=test)

```bash
# Run all tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Run specific file
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb

# Run specific test by line number
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb:25

# With documentation format
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format documentation
```

### Rails Console

```bash
# Development console
docker compose exec app bin/rails console

# One-off commands
docker compose exec -T app bin/rails runner "puts User.count"
```

### Database

```bash
docker compose exec -T app bin/rails db:migrate
docker compose exec -T app bin/rails db:seed
docker compose exec -T app bin/rails db:drop db:create db:migrate db:seed
```

### Code Quality

```bash
# RuboCop (run before committing)
docker compose exec -T app bundle exec rubocop -A

# Packwerk boundaries
docker compose exec app bundle exec packwerk check
```

### Docker

```bash
docker compose up                    # Start all services
docker compose down                  # Stop everything
docker compose build --no-cache      # Rebuild containers
docker compose logs -f app           # View logs
```

App runs at: http://localhost:3005

---

## Architecture Quick Reference

### Layer Map

| Layer | Location | Purpose |
|-------|----------|---------|
| Models | `app/models/` | Thin ActiveRecord (associations only) |
| Structs | `app/db/structs/` | Immutable domain objects |
| Repos | `app/db/repos/` | Data access (returns structs) |
| Operations | `app/operations/` | Business logic (dry-monads) |
| Contracts | `app/operations/contracts/` | Input validation |
| Controllers | `app/web/controllers/` | Thin HTTP adapters |
| Parts | `app/web/parts/` | Presentation decorators |
| Views | `app/views/` | ERB templates |
| Broadcasters | `app/broadcasters/` | Real-time Turbo Streams |

### Naming Conventions

- **Model**: `User` → `app/models/user.rb`
- **Struct**: `Structs::User` → `app/db/structs/user.rb`
- **Summary**: `Structs::UserSummary` → `app/db/structs/user_summary.rb`
- **Repo**: `UserRepo` → `app/db/repos/user_repo.rb`
- **Operation**: `Operations::Users::Create` → `app/operations/users/create.rb`
- **Contract**: `Operations::Contracts::CreateUser` → `app/operations/contracts/create_user.rb`
- **Controller**: `Admin::UsersController` → `app/web/controllers/admin/users_controller.rb`
- **Part**: `Web::Parts::User` → `app/web/parts/user.rb`
- **Broadcaster**: `IncidentBroadcaster` → `app/broadcasters/incident_broadcaster.rb`

### DI Container Keys

```ruby
AppContainer["repos.user"]            # => UserRepo
AppContainer["repos.incident"]        # => IncidentRepo
AppContainer["parts.factory"]         # => Web::Parts::Factory
AppContainer["broadcasters.incident"] # => IncidentBroadcaster
```

### Dependencies Flow (Enforced by Packwerk)

```
app/web → app/operations → app/db → app/models
```

**Never upward!**

---

## Key Patterns

### Struct Usage

| Scenario | Type | Class |
|----------|------|-------|
| Single record (`find`, `find!`) | Full struct | `Structs::User` (dry-struct) |
| Collections (`all`, `where`) | Summary | `Structs::UserSummary` (Ruby Data) |

### Operation Results

Operations return `Success(data)` or `Failure(error)`:

```ruby
case result
in Success(user)
  # handle success
in Failure(:invalid_credentials)
  # handle specific failure
in Failure(errors)
  # handle validation errors hash
end
```

### Parts Factory

```ruby
factory = AppContainer["parts.factory"]
@user = factory.wrap(user_struct)           # Single
@users = factory.wrap_many(user_structs)    # Collection
```

---

## Development Users

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@ismf-ski.com | password123 |
| Referee | referee@ismf-ski.com | password123 |
| VAR Operator | var@ismf-ski.com | password123 |
| User | user@example.com | password123 |

---

## Testing Strategy

| Layer | Location | What to Test |
|-------|----------|--------------|
| Models | `spec/models/` | Associations, validations |
| Repos | `spec/db/repos/` | Queries, struct building |
| Structs | `spec/db/structs/` | Attributes, domain methods |
| Operations | `spec/operations/` | Business logic |
| Requests | `spec/requests/` | Full HTTP stack |

---

## Code Quality Rules

### RuboCop Enforces

- ✅ Frozen string literals on all files
- ✅ Documentation for repos, operations, lib code
- ✅ Method length ≤25 lines
- ✅ ABC complexity ≤25

### Packwerk Enforces

- ✅ Layer boundaries (no upward dependencies)
- ✅ Clean violations before merging

---

## Documentation

- **Full Architecture**: `docs/ARCHITECTURE.md`
- **Feature Workflow**: `.rules` (Zed AI assistant workflow)