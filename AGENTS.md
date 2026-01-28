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

---

## Agent Inventory

### 1. feature-bootstrapper

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

### 2. rails-test-runner

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

### 3. rails-console-runner

**Purpose:** Execute Ruby code in Rails console context.

**When to Use:**
- Exploring data via repos
- Testing operations manually
- Debugging domain logic
- Checking DI container registrations

**When NOT to Use:**
- Modifying production data
- Running migrations
- Long-running processes

**Required Input:**
- Ruby code to execute

**Expected Output:**
- Console output / return values

**Command Pattern:**
```bash
docker compose exec app bin/rails console
# OR for one-liners:
docker compose exec -T app bin/rails runner "code"
```

---

### 4. code-quality-checker

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

### 5. api-tester

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

### 6. docker-diagnose

**Purpose:** Diagnose Docker container issues.

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

### 7. migration-generator

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

## Agent Selection Guide

| Problem | Agent |
|---------|-------|
| "Build a new feature" | `feature-bootstrapper` |
| "Run my tests" | `rails-test-runner` |
| "Check this in console" | `rails-console-runner` |
| "Verify code quality" | `code-quality-checker` |
| "Test this endpoint" | `api-tester` |
| "Container won't start" | `docker-diagnose` |
| "Add a database column" | `migration-generator` |

---

## Global vs Project Agents

### Project-Scoped (this repo)
These agents read project-specific documentation:
- `feature-bootstrapper` — reads `docs/ARCHITECTURE.md`, `docs/FEATURE_WORKFLOW.md`
- `rails-test-runner` — knows Docker command patterns
- `rails-console-runner` — knows DI container keys

### Globally Reusable
These agents work across projects:
- `docker-diagnose` — generic Docker troubleshooting
- `code-quality-checker` — runs standard linters

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