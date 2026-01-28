# Feature Development Workflow

> Mandatory workflow when `@feature` is mentioned or a new feature is requested.

This document defines the phases that MUST be followed when building new features in the ISMF Race Logger project.

---

## Overview

```
Phase 1: Requirements Gathering
         ↓
Phase 2: Solution Proposal
         ↓
Phase 3: Implementation
         ↓
Phase 4: Testing & Quality Gates
```

**You MUST NOT skip phases.**

---

## Phase 1: Requirements Gathering

You MUST ask these questions ONE BY ONE. Wait for the user's answer before asking the next question.

### Questions (in order)

1. **Feature Name**
   > "What is the name/title of this feature?"
   
   Example: "Admin Incidents Management"

2. **Resource/Model**
   > "What is the main resource/model?"
   
   If new model:
   > "What attributes/fields does it need?"
   
   Example: `name:string, description:text, status:string, bib_number:integer, race_id:references`

3. **Views Needed**
   > "Which views do you need?"
   
   Options:
   - [ ] Index (list)
   - [ ] Show (detail)
   - [ ] New/Create form
   - [ ] Edit/Update form
   - [ ] Delete confirmation

4. **Platform Support**
   > "Desktop only, or also mobile/Turbo Native?"

5. **Real-time Features**
   > "Any real-time updates needed?" (Turbo Streams broadcasting)

6. **Authorization**
   > "Who can access this?"
   
   Options: admin only, referees, var_operators, public

7. **Special Requirements**
   > "Any special validations, workflows, or integrations?"

---

## Phase 2: Solution Proposal

After gathering all requirements, you MUST present a complete proposal.

### Proposal Structure

#### 1. Files to Create (grouped by layer)

| Layer | Files |
|-------|-------|
| Migration | `db/migrate/XXXXXX_create_*.rb` |
| Model | `app/models/*.rb` |
| Struct (full) | `app/db/structs/*.rb` |
| Struct (summary) | `app/db/structs/*_summary.rb` |
| Repo | `app/db/repos/*_repo.rb` |
| Contract | `app/operations/contracts/*.rb` |
| Operation(s) | `app/operations/*/create.rb`, etc. |
| Controller | `app/web/controllers/**/*.rb` |
| Part | `app/web/parts/*.rb` |
| Views | `app/views/**/*.html.erb` |
| Broadcaster | `app/broadcasters/*_broadcaster.rb` (if real-time) |
| Policy | `app/policies/*_policy.rb` (if authorization) |
| Tests | `spec/**/*_spec.rb` |

#### 2. Architecture Decisions

You MUST document:
- Struct type: `dry-struct` (single) vs Ruby `Data` (collections)
- Authorization strategy (Pundit policy rules)
- Broadcasting strategy (stream names, events)
- Any deviations from standard patterns (with justification)

#### 3. Request Approval

> "Does this plan look good? Any changes before I start?"

You MUST wait for explicit approval before proceeding.

---

## Phase 3: Implementation

After approval, create files in this order:

### Implementation Order

1. **Migration** — Database schema
2. **Model** — Thin ActiveRecord (associations only)
3. **Struct(s)** — Full struct and summary struct
4. **Repo** — Data access layer
5. **Contract(s)** — Input validation
6. **Operation(s)** — Business logic
7. **Controller** — HTTP adapter
8. **Part** — Presentation logic
9. **Views/Templates** — ERB templates
10. **Broadcaster** — Real-time updates (if needed)
11. **Policy** — Authorization (if needed)
12. **Routes** — Add to `config/routes.rb`
13. **Container** — Register in `config/initializers/container.rb` (if needed)

### Implementation Rules

- Use templates from `templates/` directory
- Follow naming conventions from `.rules`
- Add `# frozen_string_literal: true` to all Ruby files
- Include documentation comments for repos, operations, lib code
- Resolve dependencies via `AppContainer`

---

## Phase 4: Testing & Quality Gates

You MUST complete all quality gates before declaring the feature complete.

### 4.1 Write Tests

Create test files for:

| Layer | Location | What to Test |
|-------|----------|--------------|
| Model | `spec/models/` | Associations, validations |
| Struct | `spec/db/structs/` | Attributes, domain methods |
| Repo | `spec/db/repos/` | Queries, struct building |
| Operation | `spec/operations/` | Business logic, success/failure paths |
| Request | `spec/requests/` | HTTP endpoints, authorization |
| Broadcaster | `spec/broadcasters/` | Real-time events (if applicable) |

### 4.2 Run Tests

```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format documentation
```

All tests MUST pass.

### 4.3 Fix Failures

If tests fail:
1. Analyze the failure
2. Fix the code
3. Re-run tests
4. Repeat until all pass

### 4.4 Code Quality Checks

```bash
# RuboCop
docker compose exec -T app bundle exec rubocop -A

# Packwerk
docker compose exec app bundle exec packwerk check
```

Both MUST pass with no violations.

### 4.5 Completion Checklist

Before declaring complete, verify:

- [ ] All files created per proposal
- [ ] All tests pass
- [ ] RuboCop passes
- [ ] Packwerk boundaries respected
- [ ] Routes added
- [ ] DI container updated (if needed)
- [ ] Documentation updated (if needed)

---

## Quick Reference

### Struct Decision Table

| Scenario | Type | Class Pattern |
|----------|------|---------------|
| `find(id)`, `find!`, `find_by` | Full | `Structs::Resource` |
| `all`, `where`, `search` | Summary | `Structs::ResourceSummary` |

### Operation Result Patterns

```ruby
# Success path
Success(resource)

# Failure paths
Failure(:not_found)
Failure(:unauthorized)
Failure(errors)  # validation errors hash
```

### Controller Pattern Matching

```ruby
case result
in Success(resource)
  redirect_to path, notice: "Success!"
in Failure(:not_found)
  head :not_found
in Failure(errors)
  @errors = errors
  render :new, status: :unprocessable_entity
end
```

---

## Anti-Patterns (MUST NOT)

- ❌ Skip requirements gathering
- ❌ Implement without proposal approval
- ❌ Skip tests
- ❌ Ignore failing tests
- ❌ Skip code quality checks
- ❌ Put business logic in controllers
- ❌ Put presentation logic in structs
- ❌ Hard-code repo/part instantiation
- ❌ Create files in wrong order (causes dependency issues)

---

## See Also

- `.rules` — AI constraints
- `docs/ARCHITECTURE.md` — Full architecture details
- `docs/DEV_COMMANDS.md` — All shell commands
- `templates/` — Code templates