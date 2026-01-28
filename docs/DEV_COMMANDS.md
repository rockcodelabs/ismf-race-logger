# Development Commands

> All shell commands for the ISMF Race Logger project.
> Copy-paste safe. Docker-only execution.

---

## Testing

### Run Tests (CRITICAL: Always use RAILS_ENV=test)

```bash
# Run all tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Run specific file
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb

# Run specific test by line number
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb:25

# With documentation format
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format documentation

# Run tests by layer
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/models/
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/db/repos/
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/operations/
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/
```

**Why RAILS_ENV=test?** The Docker container defaults to development. Without it, tests fail with 403 Forbidden due to host authorization.

---

## Rails Console & Runner

### Development Environment

```bash
# Interactive console
docker compose exec app bin/rails console

# Run one-liner Ruby code
docker compose exec -T app bin/rails runner "puts User.count"

# Run multi-line Ruby code
docker compose exec -T app bin/rails runner "
  user = User.find_by(email_address: 'test@example.com')
  user.update(password: 'newpass', password_confirmation: 'newpass')
  puts 'Updated: ' + user.email_address
"

# Console with DI container examples
# > user_repo = AppContainer["repos.user"]
# > user = user_repo.find(1)
# > auth = Operations::Users::Authenticate.new
# > result = auth.call(email: "test@example.com", password: "password")
```

### Test Environment

```bash
# Interactive console in test environment
docker compose exec -e RAILS_ENV=test app bin/rails console

# Run code in test environment
docker compose exec -T -e RAILS_ENV=test app bin/rails runner "puts User.count"
```

### Production Environment

**Important:** Always check container name first, as it changes with each deploy.

```bash
# Step 1: Get current production container ID
ssh rege@pi5main.local "docker ps | grep ismf-race-logger-web"

# Step 2: Use the container ID from above (example: ismf-race-logger-web-abc123)

# Interactive console
ssh rege@pi5main.local "docker exec -it ismf-race-logger-web-abc123 bin/rails console"

# Run one-liner (escape quotes carefully)
ssh rege@pi5main.local 'docker exec ismf-race-logger-web-abc123 bin/rails runner "puts User.count"'

# Run script file (for complex operations)
# 1. Create script locally in tmp/
# 2. Copy to server
scp tmp/script.rb rege@pi5main.local:/tmp/script.rb
# 3. Copy into container and execute
ssh rege@pi5main.local 'docker cp /tmp/script.rb ismf-race-logger-web-abc123:/tmp/script.rb && docker exec ismf-race-logger-web-abc123 bin/rails runner /tmp/script.rb'
```

**Alternative: Using Kamal (if installed)**

```bash
# Interactive console
kamal app exec --interactive "bin/rails console"

# Run one-liner
kamal app exec "bin/rails runner 'puts User.count'"
```

---

## Database

```bash
# Run migrations
docker compose exec -T app bin/rails db:migrate

# Seed data
docker compose exec -T app bin/rails db:seed

# Reset database (drop, create, migrate, seed)
docker compose exec -T app bin/rails db:drop db:create db:migrate db:seed

# Generate migration
docker compose exec -T app bin/rails generate migration AddFieldToTable field:type

# Rollback last migration
docker compose exec -T app bin/rails db:rollback

# Check migration status
docker compose exec -T app bin/rails db:migrate:status
```

---

## Code Quality

### RuboCop (Style & Architecture)

```bash
# Check for issues
docker compose exec -T app bundle exec rubocop

# Auto-fix simple issues (recommended before commit)
docker compose exec -T app bundle exec rubocop -A

# Check specific file
docker compose exec -T app bundle exec rubocop app/operations/users/create.rb
```

### Packwerk (Architecture Boundaries)

```bash
# Check boundaries
docker compose exec app bundle exec packwerk check

# Update todo file (for existing violations only)
docker compose exec app bundle exec packwerk update-todo

# Validate configuration
docker compose exec app bundle exec packwerk validate
```

---

## Docker

```bash
# Start all services
docker compose up

# Start in background
docker compose up -d

# Stop all services
docker compose down

# Rebuild containers (after Dockerfile changes)
docker compose build --no-cache

# View logs
docker compose logs -f app

# View logs for specific service
docker compose logs -f app
docker compose logs -f postgres

# Open bash shell in container
docker compose exec app bash

# Remove stale PID file (if "server already running" error)
docker compose exec app rm -f tmp/pids/server.pid
```

---

## API Testing with curl

### Authentication

```bash
# Login (get session cookie)
curl -c cookies.txt -X POST http://localhost:3005/session \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email_address=admin@ismf-ski.com&password=password123"

# Logout
curl -b cookies.txt -X DELETE http://localhost:3005/session
```

### Authenticated Requests

```bash
# GET request
curl -b cookies.txt http://localhost:3005/admin/dashboard

# GET with JSON response
curl -b cookies.txt -H "Accept: application/json" http://localhost:3005/admin/users

# POST with form data
curl -b cookies.txt -X POST http://localhost:3005/admin/incidents \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "incident[name]=Test&incident[description]=Test%20incident"

# POST with JSON
curl -b cookies.txt -X POST http://localhost:3005/admin/incidents \
  -H "Content-Type: application/json" \
  -d '{"incident": {"name": "Test", "description": "Test incident"}}'

# PATCH/PUT
curl -b cookies.txt -X PATCH http://localhost:3005/admin/incidents/1 \
  -H "Content-Type: application/json" \
  -d '{"incident": {"status": "reviewed"}}'

# DELETE
curl -b cookies.txt -X DELETE http://localhost:3005/admin/incidents/1
```

---

## Generators

```bash
# Generate model
docker compose exec -T app bin/rails generate model Incident name:string description:text

# Generate migration
docker compose exec -T app bin/rails generate migration AddStatusToIncidents status:string

# Generate controller (avoid - prefer manual creation for architecture compliance)
# docker compose exec -T app bin/rails generate controller Admin::Incidents
```

---

## Default Development Users

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@ismf-ski.com | password123 |
| Admin | dariusz.finster@gmail.com | test |
| Referee | referee@ismf-ski.com | password123 |
| VAR Operator | var@ismf-ski.com | password123 |
| User | user@example.com | password123 |

---

## Services

| Service | Container | Port |
|---------|-----------|------|
| Rails App | ismf-app | 3005 |
| PostgreSQL | ismf-postgres | 5433 |
| Tailwind | ismf-tailwind | - |

App URL: http://localhost:3005

---

## Troubleshooting

### "Server already running" error

```bash
docker compose exec app rm -f tmp/pids/server.pid
# Or rebuild:
docker compose down
docker compose up --build
```

### Tests failing with 403 Forbidden

Ensure you're using `-e RAILS_ENV=test`:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec
```

### Database connection issues

```bash
# Check if postgres is running
docker compose ps

# Restart postgres
docker compose restart postgres

# Check database exists
docker compose exec -T app bin/rails db:version
```

---

## Kamal Deployment

### Deploy to Production

```bash
# Full deployment (build, push, deploy)
kamal deploy

# Deploy without building (use existing image)
kamal deploy --skip-push

# View deployment logs
kamal app logs -f

# Check app status
kamal app details
```

### Production Commands via Kamal

```bash
# Run migrations
kamal app exec "bin/rails db:migrate"

# Seed database
kamal app exec "bin/rails db:seed"

# Open console
kamal app exec --interactive "bin/rails console"

# View logs
kamal app logs -f

# Restart app
kamal app restart

# SSH into server
ssh rege@pi5main.local
```

### Production Server Info

- **Host:** pi5main.local
- **User:** rege
- **Service:** ismf-race-logger
- **Registry:** regedarek/ismf-race-logger
- **Container naming:** ismf-race-logger-web-{hash}

**Important:** After fixing code issues (like Zeitwerk), always deploy before running production commands.
```

