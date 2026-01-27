# ISMF Race Logger - Architecture Documentation

## Overview

This directory contains comprehensive documentation for the ISMF Race Logger's **Hanami-compatible architecture**. The application is built using Rails 8.1 as an adapter layer, with a framework-agnostic core designed for easy migration to Hanami 2.

**IMPORTANT**: We do NOT install the Hanami gem in this Rails application. We use only **dry-rb gems** to build a Hanami-compatible architecture. Migration to actual Hanami 2 happens later as a separate project/deployment.

## Quick Links

### 📚 Essential Reading (Start Here)

1. **[Getting Started Guide](./getting-started-hanami-architecture.md)**  
   *Start here if you're new to the architecture*
   - How to add features
   - Understanding the layers
   - Common tasks and patterns
   - Quick reference

2. **[Architecture Comparison](./architecture-comparison.md)**  
   *Why we chose this architecture*
   - Traditional Rails vs Hanami-compatible
   - Code examples
   - Benefits and trade-offs

### 🏗️ Implementation

3. **[Hanami Architecture Implementation Plan](./hanami-architecture-implementation-plan.md)**  
   *Complete implementation guide*
   - Phase-by-phase setup
   - Layer responsibilities
   - Code examples for each layer
   - Testing strategies

4. **[Packwerk Boundaries](./packwerk-boundaries.md)**  
   *Enforcing architectural integrity*
   - Package definitions
   - Dependency rules
   - Common violations and fixes
   - CI/CD integration

### 🔄 Future Migration

5. **[Hanami Migration Guide](./hanami-migration-guide.md)**  
   *When you're ready to migrate*
   - Step-by-step migration process
   - Expected effort (1-2 weeks)
   - Layer-by-layer changes
   - Rollback plan

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│  WEB LAYER (app/web)                                    │
│  Controllers, Views, Components - HTTP adapter          │
│  Dependencies: Application, Domain                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  APPLICATION LAYER (app/application)                    │
│  Commands, Queries, Use Cases - Orchestration           │
│  Dependencies: Domain only                              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  DOMAIN LAYER (app/domain)                              │
│  Entities, Value Objects, Contracts - Pure logic        │
│  Dependencies: NONE (framework-agnostic)                │
└─────────────────────────────────────────────────────────┘
                          ↑
┌─────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE LAYER (app/infrastructure)              │
│  Records, Repositories, Jobs - I/O adapters             │
│  Dependencies: Domain (for mapping)                     │
└─────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. Rails is an Adapter
Rails provides HTTP handling, but business logic lives in framework-agnostic layers.

### 2. Dependencies Flow Downward
- Web → Application → Domain
- Infrastructure → Domain (read-only)
- **Never upward** (enforced by Packwerk)

### 3. Business Logic in Domain
All business rules, validations, and calculations belong in the domain layer using dry-rb.

### 4. Thin Controllers
Controllers are adapters that delegate to the application layer. No business logic.

### 5. No ActiveRecord God Objects
ActiveRecord models (called "Records") are pure data mappers with no logic or callbacks.

## Technology Stack

### Domain & Application Layers (Pure dry-rb)
- **dry-struct** - Entities and value objects
- **dry-types** - Type system
- **dry-validation** - Validation contracts
- **dry-monads** - Result objects and error handling
- **dry-auto_inject** - Dependency injection
- **dry-container** - Service container

**Note**: We do NOT use the Hanami gem. Only dry-rb gems.

### Infrastructure Layer
- **ActiveRecord** - Persistence (will migrate to ROM)
- **ActiveJob** - Background processing
- **ActiveStorage** - File uploads
- **ActiveMailer** - Email delivery

### Web Layer
- **Rails 8.1** - HTTP framework
- **Turbo** - Real-time updates
- **Stimulus** - JavaScript sprinkles
- **ViewComponent** - Reusable UI components

### Architecture Enforcement
- **Packwerk** - Package boundaries and dependency rules

## Directory Structure

```
app/
├── domain/                    # ⚡ Pure business logic
│   ├── entities/              #    Business objects
│   ├── value_objects/         #    Immutable data
│   ├── contracts/             #    Validation rules
│   ├── services/              #    Pure calculations
│   └── types.rb               #    Custom types
│
├── application/               # 🎯 Use cases
│   ├── commands/              #    Write operations
│   ├── queries/               #    Read operations
│   ├── contracts/             #    Input validation
│   └── container.rb           #    DI container
│
├── infrastructure/            # 🔧 Adapters
│   ├── persistence/
│   │   ├── records/           #    ActiveRecord models
│   │   └── repositories/      #    Data access layer
│   ├── jobs/                  #    Background jobs
│   ├── mailers/               #    Email senders
│   └── storage/               #    File handling
│
└── web/                       # 🌐 HTTP interface
    ├── controllers/           #    Request handlers
    ├── views/                 #    HTML templates
    └── components/            #    Reusable UI
```

## Testing Strategy

### Fast Unit Tests (Domain)
```bash
# No database, pure Ruby - ~2ms per test
bundle exec rspec spec/domain
```

### Integration Tests (Application)
```bash
# With database - ~50ms per test
bundle exec rspec spec/application
```

### Request Tests (Web)
```bash
# Full stack - ~100ms per test
bundle exec rspec spec/web
```

### Repository Tests (Infrastructure)
```bash
# Database integration - ~50ms per test
bundle exec rspec spec/infrastructure
```

## Common Commands

### Development
```bash
# Start application
docker compose up

# Run console
docker compose exec app bin/rails console

# Run tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Check architecture boundaries
docker compose exec app bundle exec packwerk check
```

### Architecture Validation
```bash
# Validate package definitions
docker compose exec app bundle exec packwerk validate

# Update Packwerk cache
docker compose exec app bundle exec packwerk update

# Check specific package
docker compose exec app bundle exec packwerk check app/domain/
```

## Adding a New Feature

### Step-by-Step Process

1. **Define business logic** in `app/domain/entities/`
2. **Create validation contract** in `app/domain/contracts/`
3. **Write domain tests** (fast, no database)
4. **Create command/query** in `app/application/`
5. **Add repository methods** in `app/infrastructure/`
6. **Create controller action** in `app/web/`
7. **Register in container** (`config/initializers/dry_container.rb`)
8. **Add route** (`config/routes.rb`)
9. **Run Packwerk check** to ensure boundaries

See [Getting Started Guide](./getting-started-hanami-architecture.md) for detailed examples.

## Migration Path to Hanami (Future)

**IMPORTANT**: This describes creating a NEW Hanami 2 project in the future, NOT installing Hanami in this Rails app.

When ready to create a Hanami version:

| Layer          | Changes Required | Estimated Time |
|----------------|------------------|----------------|
| Domain         | **0** (copy to new Hanami project) | 0 hours |
| Application    | **0** (copy to new Hanami project) | 0 hours |
| Infrastructure | Replace AR with ROM in Hanami | 16-24 hours |
| Web            | Rewrite controllers → actions | 24-40 hours |
| Configuration  | Create Hanami boot files | 8-16 hours |

**Total**: 1-2 weeks to create parallel Hanami deployment

**Current State**: Rails 8.1 + dry-rb (Hanami-compatible architecture)  
**Future State**: Separate Hanami 2 project (blue-green deployment)

See [Hanami Migration Guide](./hanami-migration-guide.md) for complete process.

## Benefits

### ✅ Framework Independence
- Domain and application layers have zero Rails dependencies
- Uses only dry-rb (no Hanami gem needed in Rails)
- Can create Hanami version by copying domain/application as-is
- Can migrate to Roda, or any framework

### ✅ Testability
- Fast unit tests (domain) - no database needed
- Clear separation enables focused testing
- 90% of tests run in milliseconds

### ✅ Maintainability
- Single responsibility per file
- Explicit dependencies
- No hidden side effects (callbacks)

### ✅ Turbo Native Compatibility
- Mobile apps (iOS/Android) unaffected by backend migration
- Business logic in domain remains stable
- APIs stay consistent

### ✅ Long-term Viability
- Not locked into Rails ecosystem (dry-rb is framework-agnostic)
- Can create Hanami version with minimal effort when ready
- Can adopt better frameworks as they emerge
- Protects 5-10+ year investment
- No need to install Hanami now; architecture ensures future compatibility

## Constraints

### ❌ Domain Cannot Use
- Rails constants (`Rails.*`)
- ActiveRecord (`ActiveRecord::Base`)
- ActiveSupport (except minimal core_ext)
- Any framework-specific code

### ❌ Application Cannot Use
- Controllers or HTTP concerns
- Direct database queries (must use repositories)
- View rendering

### ❌ Web Cannot Use
- Infrastructure layer directly
- Business logic (must delegate to application)
- Direct database access

### ❌ Infrastructure Cannot Use
- Application layer
- Web layer

**These are enforced by Packwerk.** Violations fail CI/CD.

## Further Reading

### Internal Documentation
- [Report & Incident Model](./report-incident-model.md) - Data model design
- [FOP Real-time Performance](../features/fop-realtime-performance.md) - Performance considerations
- [Implementation Plan](../implementation-plan-rails-8.1.md) - Original Rails 8.1 setup

### External Resources
- [Hanami 2 Documentation](https://guides.hanamirb.org/)
- [dry-rb Ecosystem](https://dry-rb.org/)
- [Packwerk Guide](https://github.com/Shopify/packwerk)
- [ROM (Ruby Object Mapper)](https://rom-rb.org/)

## Questions?

When deciding where code belongs, ask:

1. **Does it contain business rules?** → Domain
2. **Does it orchestrate operations?** → Application  
3. **Does it touch databases/APIs?** → Infrastructure
4. **Does it handle HTTP?** → Web

If still unsure, start in Application and refactor later.

## Document Index

| Document | Purpose | Audience |
|----------|---------|----------|
| [Getting Started](./getting-started-hanami-architecture.md) | Learn the architecture | New developers |
| [Architecture Comparison](./architecture-comparison.md) | Understand the decision | Everyone |
| [Implementation Plan](./hanami-architecture-implementation-plan.md) | Build the system | Implementers |
| [Packwerk Boundaries](./packwerk-boundaries.md) | Enforce rules | All developers |
| [Migration Guide](./hanami-migration-guide.md) | Future: Create Hanami version | Future teams |

---

**Architecture Version**: 1.0  
**Last Updated**: 2024  
**Status**: Active Development  
**Tech Stack**: Rails 8.1 + dry-rb (NO Hanami gem)  
**Maintained By**: ISMF Race Logger Team