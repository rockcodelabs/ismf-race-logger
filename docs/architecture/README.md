# Architecture Overview

> Hanami-Hybrid Architecture for ISMF Race Logger

This directory contains the architectural documentation for the ISMF Race Logger application. The architecture follows Hanami 2.x conventions using Rails 8.1 + dry-rb gems, with full support for Turbo, Hotwire, and Turbo Native.

---

## Quick Start

| Document | Focus | Read When |
|----------|-------|-----------|
| [Hanami Hybrid Architecture](./hanami-hybrid-architecture.md) | DB layer, Operations, Structs, Repos | Working on data access or business logic |
| [Web Layer Architecture](./web-layer.md) | Controllers, Parts, Templates, Broadcasters | Working on HTTP, views, or real-time features |

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                         Web Layer                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Controllers │  │    Parts    │  │       Templates         │  │
│  │   (thin)    │  │ (decorate)  │  │  (.turbo_native.erb)    │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────────────────┬─┘  │
│         │                │                                  │    │
│         │         ┌──────┴──────┐                          │    │
│         │         │   Factory   │                          │    │
│         │         └─────────────┘                          │    │
│         │                                                   │    │
│  ┌──────┴──────────────────────────────────────────────────┴┐   │
│  │                     Broadcasters                          │   │
│  │              (real-time Turbo Streams)                    │   │
│  └───────────────────────────┬───────────────────────────────┘   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
┌──────────────────────────────┼───────────────────────────────────┐
│                    Operations Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Commands   │  │   Queries   │  │       Contracts         │  │
│  │  (Create)   │  │   (Find)    │  │   (dry-validation)      │  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────────┘  │
│         │                │                                       │
│         └────────┬───────┘                                       │
│                  │ dry-monads (Success/Failure)                  │
└──────────────────┼───────────────────────────────────────────────┘
                   │
┌──────────────────┼───────────────────────────────────────────────┐
│                  │      DB Layer                                 │
│  ┌───────────────┴───────────────┐  ┌─────────────────────────┐  │
│  │            Repos              │  │         Structs         │  │
│  │   (find, all, create, etc.)   │  │  (dry-struct / Data)    │  │
│  └───────────────┬───────────────┘  └─────────────────────────┘  │
│                  │                                               │
│  ┌───────────────┴───────────────┐                               │
│  │           Models              │                               │
│  │   (thin ActiveRecord)         │                               │
│  └───────────────────────────────┘                               │
└──────────────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Models** | `app/models/` | Thin ActiveRecord (associations only, no logic) |
| **Structs** | `app/db/structs/` | Immutable domain objects (dry-struct + Ruby Data) |
| **Repos** | `app/db/repos/` | Data access (returns structs, not AR models) |
| **Operations** | `app/operations/` | Business logic (dry-monads, dry-validation) |
| **Controllers** | `app/web/controllers/` | Thin HTTP adapters (call operations) |
| **Parts** | `app/web/parts/` | View presentation logic (wrap structs) |
| **Templates** | `app/web/templates/` | ERB views (use parts, no logic) |
| **Broadcasters** | `app/broadcasters/` | Real-time Turbo Stream delivery |

---

## Key Patterns

### Data Flow

```
Request → Controller → Operation → Repo → Database
                ↓           ↓
          Broadcaster    Struct
                ↓           ↓
              Part     ← Factory
                ↓
            Template
                ↓
         Turbo Stream → All Clients
```

### Object Types

| Layer | Object | Purpose |
|-------|--------|---------|
| Database | `User` (AR) | Persistence |
| Repo | `Structs::User` | Domain data |
| Operation | `Structs::User` | Business result |
| Broadcaster | `Web::Parts::User` | Presentation |
| Template | `Web::Parts::User` | View rendering |

### Performance

| Use Case | Struct Type | Speed |
|----------|-------------|-------|
| Single record | dry-struct (`Structs::User`) | Type-safe |
| Collections | Ruby Data (`Structs::UserSummary`) | 7x faster |

---

## Dependency Injection

All components are registered in the DI container:

```ruby
# Repos
AppContainer["repos.user"]            # => UserRepo
AppContainer["repos.incident"]        # => IncidentRepo

# Parts
AppContainer["parts.factory"]         # => Web::Parts::Factory

# Broadcasters  
AppContainer["broadcasters.incident"] # => IncidentBroadcaster
```

Usage in Operations:
```ruby
class Operations::Incidents::Create
  include Import["repos.incident", "repos.race"]
  
  def call(params)
    # repos are injected
  end
end
```

---

## Real-Time Features

### Turbo Streams

- **Broadcasters** wrap structs in Parts before rendering
- **Partials** receive Parts with presentation methods
- **Subscribers** receive real-time DOM updates

### Turbo Native

- Automatic variant detection via `request.variant = :turbo_native`
- Shared templates with `.turbo_native.html.erb` overrides
- Same codebase for web + iOS + Android

---

## Boundary Enforcement

Packwerk enforces layer separation:

```
app/web     → app/operations → app/db → app/models
    ↓
app/broadcasters
```

**No upward dependencies allowed!**

```bash
# Check boundaries
docker compose exec app bundle exec packwerk check
```

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Rails 8.1 |
| Ruby | 3.4.8 |
| Types | dry-struct, dry-types |
| Validation | dry-validation |
| Results | dry-monads |
| DI | dry-auto_inject |
| Boundaries | Packwerk |
| Real-time | Turbo Streams, Solid Cable |
| Frontend | Hotwire (Turbo + Stimulus) |
| Mobile | Turbo Native |
| CSS | TailwindCSS v4 |

---

## Documentation Index

1. **[Hanami Hybrid Architecture](./hanami-hybrid-architecture.md)**
   - Models, Structs, Repos
   - Operations, Contracts
   - Dependency Injection
   - Types system
   - Packwerk configuration

2. **[Web Layer Architecture](./web-layer.md)**
   - Controllers
   - Parts (presentation decorators)
   - Templates (ERB with variants)
   - Broadcasters (real-time)
   - Turbo Native support
   - Stimulus controllers

---

**Architecture Version**: 2.0  
**Last Updated**: 2025  
**Status**: Approved