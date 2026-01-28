# Agents

> Available agents for the ISMF Race Logger project.
> This document serves as a routing table for AI and human operators.

---

## Overview

Agents are specialized tools that solve specific problems. Each agent has a defined scope, required input, and expected output.

Use this document to:
- Understand what agents are available
- Know when to use (or not use) each agent
- Provide correct input format

**Important:** All commands shown in this document assume proper Ruby environment is active (Ruby 3.4.8 via chruby). See `.rules` section 6 for environment setup requirements.

---

## Agent Inventory

### 1. @feature

**Alias:** feature-bootstrapper

**Purpose:** Generate complete feature implementation following project architecture.

**When to Use:**
- Building new CRUD features
- Adding new models with full stack
- Creating admin pages for new resources

**When NOT to Use:**
- Small bug fixes
- Refactoring existing code
- Non-feature changes (config, deps, docs)

**Required Input:**
- Feature name
- Model/resource name
- Attributes (if new model)
- Views needed (index/show/new/edit)
- Authorization requirements

**Expected Output:**
- Migration, model, struct, repo, operation, controller, part, views, tests
- All files following project architecture

**Workflow:** See `docs/FEATURE_WORKFLOW.md`

---

### 2. @test

**Alias:** rails-test-runner

**Purpose:** Execute RSpec tests in Docker with correct environment.

**When to Use:**
- Running specific test files
- Running test suites by layer
- Debugging failing tests

**When NOT to Use:**
- You need to modify test files (use editor)
- Running non-test commands

**Required Input:**
- Test file path OR test pattern OR "all"

**Expected Output:**
- Test results with pass/fail status
- Failure details with line numbers

**Command Pattern:**
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec [path]
```

---

### 3. @console

**Purpose:** Execute Ruby code in Rails console/runner across all environments (dev/test/prod).

**When to Use:**
- Exploring data via repos
- Testing operations manually
- Updating records in any environment
- Debugging domain logic
- Checking DI container registrations

**When NOT to Use:**
- Running migrations (use db:migrate)
- Long-running processes
- Bulk data operations (write a rake task)

**Required Input:**
- Target environment: `dev` (default), `test`, or `prod`
- Execution mode: `interactive` (console) or `runner` (one-liner)
- Ruby code to execute (for runner mode)

**Expected Output:**
- Console output / return values

**Environment-Specific Behavior:**

**Development:**
```bash
# Interactive console
docker compose exec app bin/rails console

# Runner (one-liner)
docker compose exec -T app bin/rails runner "puts User.count"

# Runner (multi-line)
docker compose exec -T app bin/rails runner "
  user = User.find_by(email_address: 'test@example.com')
  puts user.name
"
```

**Test:**
```bash
# Interactive console
docker compose exec -e RAILS_ENV=test app bin/rails console

# Runner
docker compose exec -T -e RAILS_ENV=test app bin/rails runner "puts User.count"
```

**Production:**
```bash
# Interactive console
kamal app exec "bin/rails console" --reuse -i

# Runner (one-liner)
kamal app exec "bin/rails runner 'puts User.count'" --reuse

# Runner (multi-line)
kamal app exec "bin/rails runner \"
  user = User.find_by(email_address: 'test@example.com')
  puts user.name
\"" --reuse

# For complex operations, use script file:
scp tmp/script.rb rege@pi5main.local:/tmp/script.rb
ssh rege@pi5main.local "docker cp /tmp/script.rb \$(docker ps -q -f name=ismf-race-logger-web):/tmp/script.rb"
kamal app exec "bin/rails runner /tmp/script.rb" --reuse
```

**Rules:**
- Always use `-T` flag for non-interactive runner commands in dev/test
- Use single quotes inside double-quoted runner strings
- For production, use `kamal app exec` with `--reuse` flag
- Use `-i` flag for interactive console in production
- If Zeitwerk or code is broken in prod, deploy fix before running commands

---

### 4. @quality

**Alias:** code-quality-checker

**Purpose:** Run RuboCop and Packwerk to verify code quality.

**When to Use:**
- Before committing changes
- After refactoring
- Verifying architecture boundaries

**When NOT to Use:**
- During exploratory coding (run at end)

**Required Input:**
- None (runs on entire project)
- OR specific file path

**Expected Output:**
- List of violations (if any)
- Auto-fixed issues report

**Command Pattern:**
```bash
docker compose exec -T app bundle exec rubocop -A
docker compose exec app bundle exec packwerk check
```

---

### 5. @curl

**Alias:** api-tester

**Purpose:** Test HTTP endpoints using curl.

**When to Use:**
- Verifying endpoint behavior
- Testing authentication flow
- Debugging API responses

**When NOT to Use:**
- Automated testing (use RSpec request specs)
- Load testing

**Required Input:**
- HTTP method
- Endpoint path
- Request body (if applicable)
- Authentication required (yes/no)

**Expected Output:**
- HTTP response with status code
- Response body

**See:** `docs/DEV_COMMANDS.md` → API Testing with curl

---

### 6. @debug

**Alias:** docker-diagnose

**Purpose:** Diagnose Docker container issues and troubleshoot application problems.

**When to Use:**
- Container won't start
- "Server already running" errors
- Database connection issues
- Service health checks

**When NOT to Use:**
- Application-level bugs
- Test failures

**Required Input:**
- Error message or symptom description

**Expected Output:**
- Diagnosis
- Fix commands

**Common Fixes:**
```bash
# Remove stale PID
docker compose exec app rm -f tmp/pids/server.pid

# Rebuild containers
docker compose down && docker compose up --build

# Check service status
docker compose ps
```

---

### 7. @migration

**Alias:** migration-generator

**Purpose:** Generate database migrations following Rails conventions.

**When to Use:**
- Adding new tables
- Adding/removing columns
- Adding indexes
- Modifying constraints

**When NOT to Use:**
- Data migrations (use rake tasks)
- Complex schema changes (write manually)

**Required Input:**
- Migration name
- Fields with types

**Expected Output:**
- Migration file path
- Generated migration content

**Command Pattern:**
```bash
docker compose exec -T app bin/rails generate migration MigrationName field:type
```

---

### 8. @deploy

**Alias:** deployment-manager

**Purpose:** Deploy code changes to production via GitHub Actions.

**When to Use:**
- After committing code changes that need to go to production
- Checking deployment status
- Understanding the deployment workflow

**When NOT to Use:**
- For local development changes
- When changes don't need to go to production yet
- Emergency fixes (use hotfix branch workflow)

**Required Input:**
- None (automated via CI/CD)

**Expected Output:**
- Deployment status
- GitHub Actions workflow URL

**Deployment Workflow:**

This project uses **GitHub Actions for automated deployment**:

1. **Push code to GitHub:**
   ```bash
   git add .
   git commit -m "Your commit message"
   git push origin main
   ```

2. **GitHub Actions triggers automatically:**
   - Runs tests
   - Builds Docker image
   - Deploys via Kamal to production

3. **Wait for deployment to complete:**
   - Check GitHub Actions tab for workflow status
   - Deployment typically takes 3-5 minutes
   - Production will be updated automatically

4. **Verify deployment:**
   ```bash
   # Check running container version
   kamal app version --reuse
   
   # Check application logs
   kamal app logs --since 5m
   ```

**Important Notes:**
- Manual `kamal deploy` requires secrets and is NOT the normal workflow
- Always push to GitHub and let Actions handle deployment
- After code changes, wait for Actions to complete before testing in production
- Deployment secrets are stored in GitHub repository settings

**Monitoring Deployment:**
- GitHub Actions: https://github.com/YOUR_ORG/ismf-race-logger/actions
- Check commit SHA matches deployed version
- Production URL: https://ismf.taterniczek.pl

---

## Agent Selection Guide

| Problem | Agent |
|---------|-------|
| "Build a new feature" | `@feature` |
| "Run my tests" | `@test` |
| "Check this in console" | `@console` |
| "Update user in production" | `@console` (prod mode) |
| "Fix RuboCop violations" | `@quality` |
| "Test this endpoint" | `@curl` |
| "Container won't start" | `@debug` |
| "Add a database column" | `@migration` |
| "Why is this failing?" | `@debug` |
| "Verify Packwerk boundaries" | `@quality` |
| "Deploy my changes" | `@deploy` |
| "Push to production" | `@deploy` |

---

## Global vs Project Agents

### Project-Scoped (this repo)
These agents read project-specific documentation:
- `@feature` — reads `docs/ARCHITECTURE.md`, `docs/FEATURE_WORKFLOW.md`
- `@test` — knows Docker command patterns and RAILS_ENV requirements
- `@console` — knows environment-specific console/runner commands, production SSH patterns
- `@quality` — knows RuboCop and Packwerk configuration
- `@deploy` — knows GitHub Actions deployment workflow

### Globally Reusable
These agents work across projects:
- `@debug` — generic Docker troubleshooting
- `@curl` — HTTP endpoint testing
- `@migration` — Rails migration generation
- `@deploy` — CI/CD deployment patterns

---

## Adding New Agents

When adding a new agent:

1. Document in this file:
   - Purpose
   - When to Use / When NOT to Use
   - Required Input
   - Expected Output

2. If shell-based, add to `.zed/tasks.json`

3. Keep agents stateless (stdin → stdout)

---

## See Also

- `.rules` — AI constraints
- `docs/DEV_COMMANDS.md` — All shell commands
- `docs/FEATURE_WORKFLOW.md` — Feature development phases
- `docs/ARCHITECTURE.md` — Project architecture
- `.zed/tasks.json` — Zed task launchers