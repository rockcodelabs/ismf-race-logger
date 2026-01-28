# ISMF Race Logger

Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

## Features

- 🎿 Real-time incident logging for ski mountaineering races
- 👥 Multi-user collaboration with role-based access
- 📱 Responsive design + Turbo Native mobile support
- 🔐 Rails 8.1 native authentication
- ⚡ Live updates via Turbo Streams

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Ruby on Rails 8.1.2 |
| Ruby | 3.4.8 |
| Database | PostgreSQL 16 |
| Background | Solid Queue |
| Real-time | Solid Cable (Turbo Streams) |
| CSS | TailwindCSS v4 |
| Frontend | Hotwire (Turbo + Stimulus) |

## Quick Start

```bash
# 1. Clone and enter directory
git clone https://github.com/your-org/ismf-race-logger.git
cd ismf-race-logger

# 2. Build and setup
docker compose build
docker compose run --rm app bin/rails db:create db:migrate db:seed

# 3. Start the app
docker compose up
```

**App runs at:** http://localhost:3005

### Default Login

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@ismf-ski.com | password123 |
| User | user@example.com | password123 |

## Common Commands

```bash
# Start/stop
docker compose up
docker compose down

# Rails console
docker compose exec app bin/rails console

# Run tests (IMPORTANT: always use RAILS_ENV=test)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Run migrations
docker compose exec -T app bin/rails db:migrate

# Code quality
docker compose exec -T app bundle exec rubocop -A
docker compose exec app bundle exec packwerk check
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | Full Hanami-Hybrid architecture guide |
| [CLAUDE.md](CLAUDE.md) | AI assistant quick reference |
| [.rules](.rules) | Zed AI feature development workflow |

## Architecture Overview

The app uses a **Hanami-Hybrid Architecture** — Rails 8.1 structured with Hanami 2.x conventions using dry-rb gems.

```
Request → Controller → Operation → Repo → Database
               ↓           ↓
         Broadcaster    Struct
               ↓           ↓
             Part     ← Factory
               ↓
           Template
```

**Key layers:**
- `app/models/` — Thin ActiveRecord
- `app/db/repos/` — Data access (returns structs)
- `app/db/structs/` — Immutable domain objects
- `app/operations/` — Business logic (dry-monads)
- `app/web/controllers/` — Thin HTTP adapters
- `app/web/parts/` — Presentation decorators
- `app/broadcasters/` — Real-time Turbo Streams

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full details.

## Services

| Service | Container | Port |
|---------|-----------|------|
| Rails App | ismf-app | 3005 |
| PostgreSQL | ismf-postgres | 5433 |
| Tailwind | ismf-tailwind | - |

## License

© 2024-2025 International Ski Mountaineering Federation. All rights reserved.