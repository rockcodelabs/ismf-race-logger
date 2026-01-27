# Hanami-Compatible Architecture - Quick Reference Card

## Where Does My Code Go?

```
┌──────────────────────────────────────────────────────────────────┐
│ QUESTION                          → ANSWER                       │
├──────────────────────────────────────────────────────────────────┤
│ Business rule or calculation?     → app/domain/entities/         │
│ Validation logic?                 → app/domain/contracts/        │
│ Use case / workflow?              → app/application/commands/    │
│ Read-only query?                  → app/application/queries/     │
│ Database table?                   → app/infrastructure/.../records/ │
│ Database query?                   → app/infrastructure/.../repositories/ │
│ Background job?                   → app/infrastructure/jobs/     │
│ HTTP endpoint?                    → app/web/controllers/         │
│ HTML template?                    → app/web/views/               │
└──────────────────────────────────────────────────────────────────┘
```

## File Naming Conventions

| Type | Location | Example |
|------|----------|---------|
| Entity | `app/domain/entities/` | `report.rb` → `Domain::Entities::Report` |
| Value Object | `app/domain/value_objects/` | `bib_number.rb` → `Domain::ValueObjects::BibNumber` |
| Contract | `app/domain/contracts/` | `report_contract.rb` → `Domain::Contracts::ReportContract` |
| Command | `app/application/commands/` | `reports/create.rb` → `Application::Commands::Reports::Create` |
| Query | `app/application/queries/` | `reports/by_race.rb` → `Application::Queries::Reports::ByRace` |
| Record | `app/infrastructure/persistence/records/` | `report_record.rb` → `Infrastructure::Persistence::Records::ReportRecord` |
| Repository | `app/infrastructure/persistence/repositories/` | `report_repository.rb` → `Infrastructure::Persistence::Repositories::ReportRepository` |
| Controller | `app/web/controllers/` | `api/reports_controller.rb` → `Web::Controllers::Api::ReportsController` |

## Dependency Rules (Enforced by Packwerk)

```
✅ ALLOWED                              ❌ FORBIDDEN
────────────────────────────────────────────────────────────
Web → Application                       Application → Web
Web → Domain                            Application → Infrastructure (direct)
Application → Domain                    Domain → Anything
Infrastructure → Domain (read-only)     Infrastructure → Application
                                        Infrastructure → Web
```

## Layer Cheat Sheet

### Domain Layer (`app/domain/`)

**✅ Can Use:**
- `dry-struct`, `dry-types`, `dry-validation`, `dry-monads`
- Standard Ruby

**❌ Cannot Use:**
- `Rails.*`
- `ActiveRecord::Base`
- `ActiveJob`
- Any persistence
- Any HTTP concerns

**Example:**
```ruby
module Domain
  module Entities
    class Report < Dry::Struct
      attribute :bib_number, Types::Integer
      
      def summary
        "Report for Bib ##{bib_number}"  # Pure logic
      end
    end
  end
end
```

### Application Layer (`app/application/`)

**✅ Can Use:**
- Domain entities
- Repositories (via dependency injection)
- `dry-monads` for results
- `dry-auto_inject` for DI

**❌ Cannot Use:**
- Direct ActiveRecord queries
- Controllers
- Views
- Direct Infrastructure access

**Example:**
```ruby
module Application
  module Commands
    module Reports
      class Create
        include Dry::Monads[:result]
        include Import["repositories.report"]
        
        def call(params, user_id)
          report = yield report_repository.create(params)
          Success(report)
        end
      end
    end
  end
end
```

### Infrastructure Layer (`app/infrastructure/`)

**✅ Can Use:**
- ActiveRecord
- ActiveJob
- Rails adapters
- Domain entities (for mapping)

**❌ Cannot Use:**
- Application commands/queries (direct)
- Controllers
- Business logic

**Example - Record:**
```ruby
module Infrastructure
  module Persistence
    module Records
      class ReportRecord < ApplicationRecord
        self.table_name = "reports"
        
        # NO validations
        # NO callbacks
        # NO business logic
        
        scope :ordered, -> { order(created_at: :desc) }
      end
    end
  end
end
```

**Example - Repository:**
```ruby
module Infrastructure
  module Persistence
    module Repositories
      class ReportRepository
        include Dry::Monads[:result]
        
        def create(attributes)
          record = Records::ReportRecord.new(attributes)
          record.save ? Success(to_entity(record)) : Failure(record.errors)
        end
        
        private
        
        def to_entity(record)
          Domain::Entities::Report.new(
            id: record.id,
            bib_number: record.bib_number
            # Map all attributes
          )
        end
      end
    end
  end
end
```

### Web Layer (`app/web/`)

**✅ Can Use:**
- Application commands/queries (via DI)
- Domain entities (read-only)
- Rails controllers/views

**❌ Cannot Use:**
- Direct Infrastructure access
- Business logic in controllers
- Direct ActiveRecord queries

**Example:**
```ruby
module Web
  module Controllers
    module Api
      class ReportsController < ApplicationController
        def create
          result = create_report_command.call(params, current_user.id)
          
          result.either(
            ->(report) { render json: report, status: :created },
            ->(error) { render json: { error: error }, status: 422 }
          )
        end
        
        private
        
        def create_report_command
          ApplicationContainer.resolve("commands.reports.create")
        end
      end
    end
  end
end
```

## Common Patterns

### Pattern 1: Create a Resource

```ruby
# 1. Domain Entity
class Report < Dry::Struct
  attribute :bib_number, Types::Integer
end

# 2. Domain Contract
class ReportContract < Dry::Validation::Contract
  params do
    required(:bib_number).filled(:integer)
  end
end

# 3. Application Command
class Create
  include Dry::Monads[:result]
  include Import["repositories.report"]
  
  def call(params)
    validated = yield validate(params)
    report = yield report_repository.create(validated)
    Success(report)
  end
end

# 4. Controller
def create
  result = create_command.call(params)
  handle_result(result)
end
```

### Pattern 2: Query Data

```ruby
# 1. Application Query
class ByRace
  include Dry::Monads[:result]
  include Import["repositories.report"]
  
  def call(race_id)
    report_repository.by_race(race_id)
  end
end

# 2. Repository Method
def by_race(race_id)
  records = Records::ReportRecord.where(race_id: race_id).to_a
  Success(records.map { |r| to_entity(r) })
end

# 3. Controller
def index
  result = by_race_query.call(params[:race_id])
  result.either(
    ->(reports) { render :index, locals: { reports: reports } },
    ->(error) { redirect_to root_path, alert: "Error" }
  )
end
```

### Pattern 3: Background Job

```ruby
# 1. Application Command triggers job
def call(report_id)
  report = yield report_repository.find(report_id)
  
  # Trigger infrastructure job
  ProcessVideoJob.perform_later(report.id)
  
  Success(report)
end

# 2. Infrastructure Job
class ProcessVideoJob < ApplicationJob
  def perform(report_id)
    record = Records::ReportRecord.find(report_id)
    # Infrastructure work (video processing)
    record.video.variant(resize: [1920, 1080]).processed
  end
end
```

## dry-monads Quick Reference

### Creating Results

```ruby
Success(value)           # Happy path
Failure(error)           # Error path
Failure([:type, data])   # Structured error
```

### Using Results

```ruby
# Pattern matching
result.either(
  ->(value) { puts "Success: #{value}" },
  ->(error) { puts "Error: #{error}" }
)

# Unwrap value
result.value!            # Raises if Failure
result.value_or(default) # Returns default if Failure

# Check status
result.success?          # => true/false
result.failure?          # => true/false
```

### Do Notation (Early Return)

```ruby
include Dry::Monads::Do.for(:call)

def call(params)
  user = yield find_user(params[:user_id])      # Returns if Failure
  report = yield create_report(params)          # Returns if Failure
  
  Success([user, report])                       # Only if all succeed
end
```

## Common Commands

```bash
# Architecture validation
docker compose exec app bundle exec packwerk check
docker compose exec app bundle exec packwerk validate

# Testing by layer
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain        # Fast
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/application   # Medium
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure # Medium
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web           # Slow

# Rails console (access DI container)
docker compose exec app bin/rails console
> ApplicationContainer.resolve("commands.reports.create")
> ApplicationContainer.resolve("repositories.report")

# Database
docker compose exec app bin/rails db:migrate
docker compose exec app bin/rails db:seed
```

## Debugging Tips

### Access Commands in Console

```ruby
# Rails console
docker compose exec app bin/rails console

# Get command
command = ApplicationContainer.resolve("commands.reports.create")

# Test command
params = { race_id: 1, bib_number: 42, description: "Test" }
result = command.call(params, user_id: 1)

# Inspect result
result.success?  # => true/false
result.value!    # Get value or raise
```

### Check Packwerk Violations

```bash
# Find violations
docker compose exec app bundle exec packwerk check

# Common fixes:
# - Domain using Rails? → Remove Rails, use pure Ruby
# - Web using Infrastructure? → Use Application layer instead
# - Application using ActiveRecord? → Use Repository via DI
```

## Registration Checklist

When adding a new command/query:

- [ ] Create class in `app/application/commands/` or `app/application/queries/`
- [ ] Include `Dry::Monads[:result]`
- [ ] Include `Import[...]` for dependencies
- [ ] Register in `config/initializers/dry_container.rb`
- [ ] Use in controller via `ApplicationContainer.resolve("...")`

**Example Registration:**

```ruby
# config/initializers/dry_container.rb
ApplicationContainer.register("commands.reports.create") do
  Application::Commands::Reports::Create.new
end
```

## Red Flags 🚩

If you see these, something is wrong:

- ❌ `Rails.*` in `app/domain/`
- ❌ `ActiveRecord::Base` in `app/domain/`
- ❌ Business logic in controllers
- ❌ `Infrastructure::*` accessed directly from `app/web/`
- ❌ Validations in ActiveRecord models
- ❌ Callbacks with business logic
- ❌ Fat controllers (>20 lines per action)

## Need Help?

1. **Where does code go?** → See decision tree at top
2. **How to add feature?** → See [Getting Started Guide](./getting-started-hanami-architecture.md)
3. **Packwerk errors?** → See [Packwerk Boundaries](./packwerk-boundaries.md)
4. **Architecture questions?** → See [Architecture Comparison](./architecture-comparison.md)

---

**Quick Tip**: When unsure where code belongs, ask:
- Business rule? → Domain
- Workflow? → Application
- Database/API? → Infrastructure
- HTTP? → Web

**Remember**: NO Hanami gem installed. We use only dry-rb for Hanami-compatible architecture.