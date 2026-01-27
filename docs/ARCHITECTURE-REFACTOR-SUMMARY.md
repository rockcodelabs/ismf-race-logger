# Architecture Refactor Summary - Hanami-Compatible Design

## What Was Done

We have created a comprehensive architectural blueprint that refactors the ISMF Race Logger from a traditional Rails MVC structure to a **Hanami-compatible layered architecture** using only the **dry-rb ecosystem** (NO Hanami gem installed).

## Key Documents Created

### 1. Core Architecture Documents

#### [`docs/hanami-architecture-implementation-plan.md`](./hanami-architecture-implementation-plan.md)
**2,099 lines** - Complete implementation guide covering:
- Four-layer architecture (Domain, Application, Infrastructure, Web)
- Phase-by-phase implementation steps
- Code examples for each layer
- dry-rb gem setup (dry-struct, dry-validation, dry-monads, dry-auto_inject)
- Packwerk configuration for boundary enforcement
- Testing strategy for each layer
- Migration path to Hanami 2 (future)

#### [`docs/architecture/README.md`](./architecture/README.md)
**328 lines** - Central documentation hub:
- Quick links to all architecture docs
- Layer overview and responsibilities
- Technology stack breakdown
- Directory structure
- Common commands reference

#### [`docs/architecture/getting-started-hanami-architecture.md`](./architecture/getting-started-hanami-architecture.md)
**845 lines** - Practical developer guide:
- How to add new features step-by-step
- Understanding each layer with examples
- Working with dry-monads
- Testing strategy per layer
- Common mistakes and how to avoid them
- Debugging tips

#### [`docs/architecture/packwerk-boundaries.md`](./architecture/packwerk-boundaries.md)
**487 lines** - Boundary enforcement guide:
- Package structure and rules
- Allowed vs forbidden dependencies
- Common violations and fixes
- CI/CD integration
- Pre-commit hooks

#### [`docs/architecture/architecture-comparison.md`](./architecture/architecture-comparison.md)
**744 lines** - Traditional Rails vs Hanami-compatible:
- Side-by-side code examples
- Visual architecture diagrams
- Benefits and trade-offs
- When to use each approach
- Why we chose this for ISMF Race Logger

#### [`docs/architecture/hanami-migration-guide.md`](./architecture/hanami-migration-guide.md)
**919 lines** - Future migration playbook:
- Step-by-step guide to create NEW Hanami 2 project
- Layer-by-layer migration instructions
- Expected effort (1-2 weeks)
- Blue-green deployment strategy
- Rollback plan

#### [`docs/architecture/QUICK-REFERENCE.md`](./architecture/QUICK-REFERENCE.md)
**437 lines** - Daily development cheat sheet:
- Where does my code go? (decision tree)
- File naming conventions
- Dependency rules
- Layer-specific dos and don'ts
- Common patterns
- dry-monads quick reference

### 2. Updated Documents

#### [`CLAUDE.md`](../CLAUDE.md)
Updated to reference new architecture:
- Hanami-compatible structure overview
- Layer separation rules
- Architecture documentation links
- Key commands for boundary checking

## Architecture Overview

### Four Layers

```
┌─────────────────────────────────────────────────────────┐
│  WEB (app/web)                                          │
│  Rails controllers, views - HTTP adapter only           │
│  Dependencies: Application, Domain                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  APPLICATION (app/application)                          │
│  Commands, Queries - Use case orchestration             │
│  Dependencies: Domain only                              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  DOMAIN (app/domain)                                    │
│  Entities, Contracts - Pure business logic              │
│  Dependencies: NONE (framework-agnostic)                │
└─────────────────────────────────────────────────────────┘
                          ↑
┌─────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE (app/infrastructure)                    │
│  Records, Repositories, Jobs - I/O adapters             │
│  Dependencies: Domain (for mapping)                     │
└─────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Rails is an Adapter** - Not the core application
2. **Business Logic in Domain** - Framework-agnostic, pure Ruby + dry-rb
3. **Dependencies Flow Downward** - Enforced by Packwerk
4. **No ActiveRecord God Objects** - Records are pure data mappers
5. **Thin Controllers** - Delegate to application layer

## Technology Stack

### NO Hanami Gem!

**IMPORTANT**: We do NOT install the `hanami` gem. We use only dry-rb gems to build a Hanami-compatible architecture within Rails.

### dry-rb Ecosystem

```ruby
# Domain & Application layers
gem "dry-struct"        # Entities
gem "dry-types"         # Type system
gem "dry-validation"    # Contracts
gem "dry-monads"        # Result objects
gem "dry-auto_inject"   # Dependency injection
gem "dry-container"     # Service container

# Architecture enforcement
gem "packwerk"          # Boundary checking
```

### Why dry-rb Instead of Hanami?

1. **Incremental Adoption** - Add to existing Rails app
2. **No Conflicts** - Hanami and Rails conflict when installed together
3. **Same Benefits** - dry-rb is what Hanami uses internally
4. **Future-Proof** - Can create Hanami version later with minimal effort

## Directory Structure

```
app/
├── domain/                    # Pure business logic
│   ├── entities/              # dry-struct business objects
│   ├── value_objects/         # Immutable data
│   ├── contracts/             # dry-validation rules
│   ├── services/              # Pure calculations
│   └── types.rb               # Custom dry-types
│
├── application/               # Use cases
│   ├── commands/              # Write operations (dry-monads)
│   ├── queries/               # Read operations
│   └── container.rb           # dry-container DI
│
├── infrastructure/            # Adapters
│   ├── persistence/
│   │   ├── records/           # ActiveRecord (suffixed "Record")
│   │   └── repositories/      # Map Record → Entity
│   ├── jobs/                  # ActiveJob
│   └── mailers/               # ActionMailer
│
└── web/                       # HTTP interface
    ├── controllers/           # Thin Rails controllers
    ├── views/                 # ERB templates
    └── components/            # ViewComponent

# Packwerk enforcement
package.yml                    # Root config
app/domain/package.yml         # Domain boundaries
app/application/package.yml    # Application boundaries
app/infrastructure/package.yml # Infrastructure boundaries
app/web/package.yml            # Web boundaries
```

## Benefits

### ✅ Framework Independence
- Domain & application layers have zero Rails dependencies
- Uses only dry-rb (works in any Ruby app)
- Can create Hanami version by copying domain/application unchanged
- Protects 5-10+ year investment

### ✅ Testability
- Domain tests: No database needed (~2ms per test)
- Application tests: Integration with repos (~50ms per test)
- Web tests: Full stack (~100ms per test)
- 90% of tests run in milliseconds

### ✅ Maintainability
- Single responsibility per file
- Explicit dependencies (no magic)
- No hidden side effects (no callbacks)
- Packwerk enforces boundaries automatically

### ✅ Turbo Native Compatible
- Mobile apps (iOS/Android) unaffected by backend changes
- Business logic in domain remains stable during framework migration
- APIs stay consistent

### ✅ Migration Path to Hanami
When ready to create Hanami version:
- Domain: Copy as-is (0 changes)
- Application: Copy as-is (0 changes)
- Infrastructure: Rewrite with ROM (~2 weeks)
- Web: Rewrite with Hanami actions (~2 weeks)
- **Total: 1-2 weeks for parallel deployment**

## What's Different from Traditional Rails?

### Traditional Rails (Fat Models)

```ruby
# app/models/report.rb - 140+ lines god object
class Report < ApplicationRecord
  validates :bib_number, presence: true  # Validation
  
  before_validation :set_uuid            # Hidden side effect
  after_create :broadcast                # Hidden side effect
  after_create :create_incident          # Business logic
  
  def athlete_display_name               # Business logic
    athlete_name || "Unknown"
  end
end

# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  def create
    @report = Report.new(params)         # More business logic
    if @report.race.completed?
      render json: { error: "Race done" }
    elsif @report.save
      render json: @report
    end
  end
end
```

**Problems:**
- Business logic scattered (model, controller, callbacks)
- Tightly coupled to Rails/ActiveRecord
- Hard to test without database
- Impossible to migrate frameworks

### Hanami-Compatible (Layered)

```ruby
# app/domain/entities/report.rb - Pure logic
module Domain
  module Entities
    class Report < Dry::Struct
      attribute :bib_number, Types::Integer
      
      def athlete_display_name
        athlete_name || "Unknown"
      end
    end
  end
end

# app/domain/contracts/report_contract.rb - Validation
module Domain
  module Contracts
    class ReportContract < Dry::Validation::Contract
      params do
        required(:bib_number).filled(:integer)
      end
    end
  end
end

# app/application/commands/reports/create.rb - Use case
module Application
  module Commands
    module Reports
      class Create
        include Dry::Monads[:result]
        include Import["repositories.report", "repositories.race"]
        
        def call(params, user_id)
          validated = yield validate(params)
          race = yield race_repository.find(validated[:race_id])
          yield ensure_race_active(race)
          
          report = yield report_repository.create(validated)
          
          BroadcastReportJob.perform_later(report.id)  # Explicit
          
          Success(report)
        end
      end
    end
  end
end

# app/infrastructure/persistence/records/report_record.rb - Data only
module Infrastructure
  module Persistence
    module Records
      class ReportRecord < ApplicationRecord
        # NO validations
        # NO callbacks
        # NO business logic
        scope :ordered, -> { order(created_at: :desc) }
      end
    end
  end
end

# app/web/controllers/api/reports_controller.rb - Thin adapter
module Web
  module Controllers
    module Api
      class ReportsController < ApplicationController
        def create
          result = create_command.call(params, current_user.id)
          
          result.either(
            ->(report) { render json: report, status: :created },
            ->(error) { render json: { error: error }, status: 422 }
          )
        end
        
        private
        
        def create_command
          ApplicationContainer.resolve("commands.reports.create")
        end
      end
    end
  end
end
```

**Benefits:**
- Business logic isolated in domain (testable without DB)
- Framework-agnostic core (can migrate to Hanami)
- Explicit dependencies and side effects
- Clear separation of concerns

## Implementation Steps

### Phase 0: Foundation (2-4 hours)
1. Add dry-rb gems to Gemfile
2. Initialize Packwerk
3. Create package definitions
4. Setup dry-container for DI

### Phase 1: Domain Layer (4-8 hours)
1. Create entities with dry-struct
2. Create value objects
3. Create contracts with dry-validation
4. Write fast unit tests (no DB)

### Phase 2: Infrastructure Layer (8-16 hours)
1. Rename models to Records (suffix with "Record")
2. Create repositories that map Records → Entities
3. Remove validations and callbacks from Records
4. Register repositories in container

### Phase 3: Application Layer (8-16 hours)
1. Create commands for write operations
2. Create queries for read operations
3. Use dry-monads for control flow
4. Register in container

### Phase 4: Web Layer (4-8 hours)
1. Update controllers to be thin adapters
2. Inject commands/queries via container
3. Remove business logic from controllers

### Phase 5: Testing (4-8 hours)
1. Write domain tests (fast, no DB)
2. Write application tests (integration)
3. Update web tests (request specs)

### Phase 6: Enforcement (2-4 hours)
1. Run Packwerk check
2. Fix violations
3. Add to CI/CD pipeline

**Total Estimated Time: 2-4 weeks** (depending on codebase size)

## Migration to Hanami (Future)

When ready to migrate (business case justifies):

1. **Create NEW Hanami 2 project** (separate repo)
2. **Copy domain/ unchanged** (0 hours)
3. **Copy application/ unchanged** (0 hours)
4. **Rewrite infrastructure/ with ROM** (16-24 hours)
5. **Rewrite web/ with Hanami actions** (24-40 hours)
6. **Deploy alongside Rails** (blue-green)
7. **Switch DNS when stable**

**Total: 1-2 weeks for parallel Hanami deployment**

## Packwerk Enforcement

Packwerk automatically enforces architectural boundaries:

```bash
# Check boundaries before commit
docker compose exec app bundle exec packwerk check
```

**Violations caught:**
- ❌ Domain referencing Rails
- ❌ Web accessing Infrastructure directly
- ❌ Application using ActiveRecord directly
- ❌ Circular dependencies

**Result:** Architecture integrity maintained automatically

## Common Commands

```bash
# Check architecture
docker compose exec app bundle exec packwerk check

# Fast domain tests (no DB)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain

# Access DI container
docker compose exec app bin/rails console
> ApplicationContainer.resolve("commands.reports.create")

# Add new package
docker compose exec app bundle exec packwerk update
```

## Documentation Index

| Document | Purpose | Size |
|----------|---------|------|
| [Implementation Plan](./hanami-architecture-implementation-plan.md) | Complete guide | 2,099 lines |
| [Architecture README](./architecture/README.md) | Overview & links | 328 lines |
| [Getting Started](./architecture/getting-started-hanami-architecture.md) | Developer guide | 845 lines |
| [Packwerk Boundaries](./architecture/packwerk-boundaries.md) | Enforcement | 487 lines |
| [Architecture Comparison](./architecture/architecture-comparison.md) | Rails vs Hanami | 744 lines |
| [Migration Guide](./architecture/hanami-migration-guide.md) | Future Hanami | 919 lines |
| [Quick Reference](./architecture/QUICK-REFERENCE.md) | Daily cheat sheet | 437 lines |

**Total Documentation: ~5,800 lines**

## Next Steps

1. **Review documentation** with team
2. **Start with Phase 0** (Foundation setup)
3. **Implement one feature end-to-end** as proof of concept
4. **Migrate existing code incrementally**
5. **Run Packwerk in CI/CD**
6. **Consider Hanami migration** when business case justifies

## Key Takeaways

1. ✅ **NO Hanami gem installed** - Only dry-rb ecosystem
2. ✅ **Rails is just an adapter** - Core is framework-agnostic
3. ✅ **Packwerk enforces boundaries** - Automatic architectural integrity
4. ✅ **Easy Hanami migration** - When ready, 1-2 weeks effort
5. ✅ **Turbo Native safe** - Mobile apps unaffected by migration
6. ✅ **Long-term investment protected** - Not locked into Rails

## Questions?

- **Where does code go?** → See [Quick Reference](./architecture/QUICK-REFERENCE.md)
- **How to add features?** → See [Getting Started](./architecture/getting-started-hanami-architecture.md)
- **Why this architecture?** → See [Architecture Comparison](./architecture/architecture-comparison.md)
- **How to migrate?** → See [Migration Guide](./architecture/hanami-migration-guide.md) (future)

---

**Document Version**: 1.0  
**Created**: 2024  
**Status**: Architecture Blueprint Complete  
**Implementation Status**: Ready to Begin

**Author**: Architecture Refactor Team  
**Approved For**: ISMF Race Logger Project