# ISMF Race Logger

Professional race incident tracking and management system for the International Ski Mountaineering Federation (ISMF).

## Features

- 🎿 Real-time incident logging for ski mountaineering races
- 👥 User management with admin authorization
- 📱 Responsive design optimized for field devices (tablets, phones)
- 🔐 Secure authentication with Rails 8.1 native auth
- 🐳 Docker-based development environment

## Tech Stack

- **Framework**: Ruby on Rails 8.1.2
- **Ruby**: 3.4.8
- **Database**: PostgreSQL 16
- **Background Jobs**: Solid Queue (database-backed)
- **Caching**: Solid Cache (database-backed)
- **WebSockets**: Solid Cable (database-backed)
- **CSS**: TailwindCSS v4
- **Frontend**: Hotwire (Turbo + Stimulus)

## Prerequisites

- Docker & Docker Compose
- Git

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/your-org/ismf-race-logger.git
cd ismf-race-logger
```

### 2. Build and setup

```bash
# Build containers
docker compose build

# Create database and run migrations
docker compose run --rm app bin/rails db:create db:migrate db:seed
```

### 3. Start the application

```bash
docker compose up
```

The application will be available at: **http://localhost:3003**

### Default Credentials

| Role  | Email              | Password    |
|-------|-------------------|-------------|
| Admin | admin@ismf-ski.com | password123 |
| User  | user@example.com   | password123 |

## Development Commands

```bash
# Start all containers
docker compose up

# Start in background
docker compose up -d

# Stop containers
docker compose down

# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f app

# Open Rails console
docker compose exec app bin/rails console

# Open bash shell
docker compose exec app bash

# Run migrations
docker compose exec app bin/rails db:migrate

# Reset database
docker compose exec app bin/rails db:drop db:create db:migrate db:seed

# Run tests
docker compose exec app bundle exec rspec

# Rebuild containers
docker compose build --no-cache
```

## Port Configuration

| Service    | Port |
|------------|------|
| Rails App  | 3003 |
| PostgreSQL | 5433 |

## Project Structure

```
ismf-race-logger/
├── app/
│   ├── controllers/
│   │   ├── admin/           # Admin namespace controllers
│   │   ├── home_controller.rb
│   │   └── sessions_controller.rb
│   ├── models/
│   │   └── user.rb
│   ├── views/
│   │   ├── admin/           # Admin views
│   │   ├── home/
│   │   ├── layouts/
│   │   └── sessions/
│   └── assets/
│       └── tailwind/
│           └── application.css  # ISMF branded styles
├── config/
├── db/
│   ├── migrate/
│   └── seeds.rb
├── docker-compose.yml
├── Dockerfile.dev
└── docs/                    # Documentation
```

## ISMF Brand Colors

| Color      | Hex       | Usage                    |
|------------|-----------|--------------------------|
| Navy       | `#1a1a2e` | Primary text, headers    |
| Red        | `#e94560` | Primary actions, accent  |
| Blue       | `#0f3460` | Secondary actions        |
| Gray       | `#6b7280` | Muted text               |
| Light      | `#f8fafc` | Backgrounds              |

## Environment Variables

For production deployment, configure these environment variables:

```bash
RAILS_ENV=production
SECRET_KEY_BASE=your_secret_key
DB_HOST=postgres
POSTGRES_USER=ismf_user
POSTGRES_PASSWORD=secure_password
POSTGRES_DB=ismf_race_logger_production
```

## Testing

```bash
# Run full test suite
docker compose exec app bundle exec rspec

# Run specific tests
docker compose exec app bundle exec rspec spec/models/
```

## Documentation

Additional documentation is available in the `docs/` directory:

- [Implementation Plan](docs/implementation-plan-rails-8.1.md)
- [Report & Incident Model Architecture](docs/architecture/report-incident-model.md)
- [FOP Real-Time Performance](docs/features/fop-realtime-performance.md)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

© 2024-2025 International Ski Mountaineering Federation. All rights reserved.