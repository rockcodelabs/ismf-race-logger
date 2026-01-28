# CLAUDE.md

> Quick reference for AI assistants. See detailed docs for full information.

**⚠️ Ruby Environment Required:** All Docker/Kamal commands require Ruby 3.4.8 via chruby. See `.rules` section 6.

**⚠️ Deployment:** Code changes deploy automatically via GitHub Actions. Push to main and wait 3-5 minutes. See `@deploy` agent.

## Documentation

| Document | Purpose |
|----------|---------|
| `.rules` | AI constraints and rules (READ FIRST) |
| `docs/ARCHITECTURE.md` | Full architecture details |
| `docs/DEV_COMMANDS.md` | All shell commands |
| `docs/FEATURE_WORKFLOW.md` | @feature development phases |
| `AGENTS.md` | Available agents and routing (includes @deploy) |
| `templates/` | Code templates |

## Critical Commands

```bash
# Tests (ALWAYS use RAILS_ENV=test)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Console
docker compose exec app bin/rails console

# Code quality
docker compose exec -T app bundle exec rubocop -A
docker compose exec app bundle exec packwerk check
```

## Architecture Summary

```
Request → Controller → Operation → Repo → Database
               ↓           ↓
         Broadcaster    Struct
               ↓           ↓
             Part     ← Factory
               ↓
           Template
```

## Layer Map

| Layer | Location |
|-------|----------|
| Models | `app/models/` |
| Structs | `app/db/structs/` |
| Repos | `app/db/repos/` |
| Operations | `app/operations/` |
| Controllers | `app/web/controllers/` |
| Parts | `app/web/parts/` |
| Broadcasters | `app/broadcasters/` |

## DI Container

```ruby
AppContainer["repos.user"]
AppContainer["repos.incident"]
AppContainer["parts.factory"]
AppContainer["broadcasters.incident"]
```

## Dev Users

| Email | Password |
|-------|----------|
| admin@ismf-ski.com | password123 |
| user@example.com | password123 |

---

**For all details, see `.rules` and `docs/`**