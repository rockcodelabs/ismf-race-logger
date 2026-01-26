# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview

ISMF Race Logger - Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

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

App runs at: http://localhost:3003

### Services

| Service    | Container       | Port |
|------------|-----------------|------|
| Rails App  | ismf-app        | 3003 |
| PostgreSQL | ismf-postgres   | 5433 |
| Tailwind   | ismf-tailwind   | -    |

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

# Rebuild containers
docker compose build --no-cache

# Stop everything
docker compose down
```

## Project Structure

```
ismf-race-logger/
├── app/
│   ├── controllers/
│   │   ├── admin/           # Admin namespace (requires admin role)
│   │   ├── concerns/
│   │   │   └── authentication.rb  # Rails 8.1 native auth
│   │   └── sessions_controller.rb
│   ├── models/
│   │   ├── user.rb          # has_secure_password, admin flag
│   │   ├── session.rb       # User sessions
│   │   └── current.rb       # Current.user, Current.session
│   ├── views/
│   │   ├── admin/           # Admin views
│   │   ├── layouts/
│   │   │   ├── application.html.erb
│   │   │   └── admin.html.erb
│   │   └── sessions/        # Login views
│   └── assets/
│       └── tailwind/
│           └── application.css  # ISMF brand styles
├── config/
│   ├── routes.rb
│   └── environments/
│       ├── development.rb   # Hosts: localhost, 127.0.0.1
│       └── test.rb          # Hosts cleared for testing
├── spec/
│   ├── factories/           # FactoryBot factories
│   ├── requests/            # Request specs (preferred)
│   ├── support/             # Test helpers
│   └── rails_helper.rb
├── docker-compose.yml
├── Dockerfile.dev
└── docs/                    # Feature documentation
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

## Code Style

- Models: No namespace (e.g., `User`, not `Db::User`)
- Services: TBD (will use dry-monads)
- Views: ERB with TailwindCSS classes
- Tests: RSpec with FactoryBot

## Documentation

- `docs/implementation-plan-rails-8.1.md` - Full implementation plan
- `docs/architecture/report-incident-model.md` - Data model design
- `docs/features/fop-realtime-performance.md` - Real-time features
- `.agents/` - AI agent instructions (rspec, console, etc.)