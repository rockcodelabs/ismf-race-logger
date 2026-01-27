# Architecture Comparison: Traditional Rails vs Hanami-Compatible

## Overview

This document compares the traditional Rails "MVC" architecture with our Hanami-compatible layered architecture, explaining why we chose the latter for ISMF Race Logger.

---

## Visual Comparison

### Traditional Rails Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     RAILS APPLICATION                    │
│                                                          │
│  ┌────────────┐         ┌─────────────┐                │
│  │            │         │             │                │
│  │ Controller │────────▶│    Model    │◀───────────┐   │
│  │            │         │ (ActiveRecord)             │   │
│  │  - Routes  │         │ - Validations│             │   │
│  │  - Params  │         │ - Callbacks  │             │   │
│  │  - Logic   │         │ - Business   │             │   │
│  │            │         │   Logic      │             │   │
│  └────┬───────┘         └─────────────┘             │   │
│       │                                             │   │
│       │                                             │   │
│       ▼                                             │   │
│  ┌────────────┐                                     │   │
│  │            │                                     │   │
│  │    View    │                                     │   │
│  │            │                                     │   │
│  │  - ERB     │                                     │   │
│  │  - Helpers │                                     │   │
│  │  - Logic   │                                     │   │
│  │            │                                     │   │
│  └────────────┘                                     │   │
│                                                      │   │
│  ┌──────────────────────────────────────────────────┤   │
│  │            Background Jobs                       │   │
│  │         (Directly access models)                 │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  Everything is tightly coupled to Rails                 │
└─────────────────────────────────────────────────────────┘

Problems:
❌ Business logic scattered (models, controllers, jobs)
❌ Tight coupling to Rails/ActiveRecord
❌ Hard to test in isolation
❌ Impossible to migrate to another framework
❌ Fat models become god objects
❌ Callbacks create hidden dependencies
```

### Hanami-Compatible Layered Architecture

```
┌─────────────────────────────────────────────────────────┐
│  WEB LAYER (app/web) - Rails Adapter                    │
│                                                          │
│  ┌────────────┐                                         │
│  │ Controller │ Thin adapter, no business logic         │
│  └─────┬──────┘                                         │
│        │                                                 │
└────────┼─────────────────────────────────────────────────┘
         │ Calls commands/queries
         ▼
┌─────────────────────────────────────────────────────────┐
│  APPLICATION LAYER (app/application) - Use Cases        │
│                                                          │
│  ┌──────────┐           ┌──────────┐                   │
│  │ Commands │           │ Queries  │                   │
│  │          │           │          │                   │
│  │ Orchestrate business logic      │                   │
│  └────┬─────┘           └────┬─────┘                   │
│       │                      │                          │
└───────┼──────────────────────┼──────────────────────────┘
        │ Uses domain          │ Uses repositories
        ▼                      ▼
┌─────────────────────────────────────────────────────────┐
│  DOMAIN LAYER (app/domain) - Pure Business Logic        │
│                                                          │
│  ┌──────────┐  ┌─────────────┐  ┌──────────┐          │
│  │ Entities │  │ Value       │  │Contracts │          │
│  │          │  │ Objects     │  │          │          │
│  │ Pure     │  │ Immutable   │  │Validation│          │
│  │ Logic    │  │ Data        │  │Rules     │          │
│  └──────────┘  └─────────────┘  └──────────┘          │
│                                                          │
│  NO Rails, NO ActiveRecord, NO Framework                │
└─────────────────────────────────────────────────────────┘
        ▲                      ▲
        │ Maps to entities     │ Reads for structure
        │                      │
┌───────┼──────────────────────┼──────────────────────────┐
│  INFRASTRUCTURE LAYER (app/infrastructure)              │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐     │
│  │ Repositories │  │   Records    │  │  Jobs    │     │
│  │              │  │ (ActiveRecord)│  │          │     │
│  │ Map to       │  │ No logic     │  │Side      │     │
│  │ Entities     │  │ No callbacks │  │Effects   │     │
│  └──────────────┘  └──────────────┘  └──────────┘     │
│                                                          │
│  Database, External APIs, File Storage                  │
└─────────────────────────────────────────────────────────┘

Benefits:
✅ Business logic isolated in domain
✅ Framework-agnostic core
✅ Easy to test each layer
✅ Can migrate to Hanami/other frameworks
✅ Clear separation of concerns
✅ Explicit dependencies
```

---

## Code Examples: Feature Comparison

Let's implement the same feature in both architectures: **"Create a report for a race incident"**

### Traditional Rails Approach

#### Model: `app/models/report.rb`

```ruby
class Report < ApplicationRecord
  belongs_to :race
  belongs_to :incident
  belongs_to :user
  
  has_one_attached :video
  
  # Validations mixed with business rules
  validates :bib_number, presence: true, 
            numericality: { only_integer: true, greater_than: 0, less_than: 10000 }
  validates :race_id, :user_id, presence: true
  validates :description, presence: true
  
  # Business logic in model
  validate :race_must_be_active
  
  # Callbacks for side effects
  before_validation :set_client_uuid
  after_create :broadcast_to_desktop
  after_create :create_incident_if_needed
  
  # More business logic
  scope :by_bib, ->(bib) { where(bib_number: bib) }
  scope :recent, -> { order(created_at: :desc).limit(50) }
  
  def athlete_display_name
    athlete_name || "Unknown Athlete"
  end
  
  private
  
  def race_must_be_active
    errors.add(:race, "must be active") unless race&.active?
  end
  
  def set_client_uuid
    self.client_uuid ||= SecureRandom.uuid
  end
  
  def broadcast_to_desktop
    BroadcastReportJob.perform_later(id)
  end
  
  def create_incident_if_needed
    return if incident_id.present?
    
    incident = Incident.create!(
      race_id: race_id,
      status: :unofficial,
      decision: :pending
    )
    
    update_column(:incident_id, incident.id)
  end
end

# Problems:
# - God object (140+ lines)
# - Validations + business logic + persistence all mixed
# - Callbacks create hidden side effects
# - Hard to test without database
# - Tied to Rails/ActiveRecord
# - Can't use domain logic in other contexts
```

#### Controller: `app/controllers/api/reports_controller.rb`

```ruby
class Api::ReportsController < ApplicationController
  # Business logic in controller
  def create
    @report = Report.new(report_params)
    @report.user_id = current_user.id
    
    # More business logic
    if @report.race.completed?
      render json: { error: "Race is completed" }, status: :unprocessable_entity
      return
    end
    
    if @report.save
      render json: @report, status: :created
    else
      render json: { errors: @report.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def report_params
    params.require(:report).permit(:race_id, :bib_number, :description, :client_uuid)
  end
end

# Problems:
# - Business logic in controller (race completion check)
# - Direct model access
# - Hard to reuse logic elsewhere
```

---

### Hanami-Compatible Approach

#### Domain Entity: `app/domain/entities/report.rb`

```ruby
module Domain
  module Entities
    class Report < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::Integer.optional
      attribute :client_uuid, Types::UUID
      attribute :race_id, Types::Integer
      attribute :incident_id, Types::Integer.optional
      attribute :user_id, Types::Integer
      attribute :bib_number, Types::Integer
      attribute :description, Types::String
      attribute :athlete_name, Types::String.optional
      attribute :video_url, Types::String.optional
      attribute :created_at, Types::Params::DateTime.optional

      # Pure business logic
      def athlete_display_name
        athlete_name || "Unknown Athlete"
      end

      def has_video?
        !video_url.nil?
      end
    end
  end
end

# Benefits:
# - Pure domain object
# - No Rails dependencies
# - Easy to test
# - Reusable anywhere
# - Clear, simple
```

#### Domain Contract: `app/domain/contracts/report_contract.rb`

```ruby
module Domain
  module Contracts
    class ReportContract < Dry::Validation::Contract
      params do
        required(:client_uuid).filled(Types::UUID)
        required(:race_id).filled(:integer)
        required(:user_id).filled(:integer)
        required(:bib_number).filled(:integer, gteq?: 1, lteq?: 9999)
        required(:description).filled(:string)
        optional(:athlete_name).maybe(:string)
      end

      rule(:bib_number) do
        key.failure("must be between 1 and 9999") unless value.between?(1, 9999)
      end
    end
  end
end

# Benefits:
# - Validation separate from entity
# - Reusable across contexts
# - Framework-agnostic
```

#### Application Command: `app/application/commands/reports/create.rb`

```ruby
module Application
  module Commands
    module Reports
      class Create
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.report", "repositories.race", "repositories.incident"]

        def call(params, current_user_id)
          # Validate input
          validated = yield validate(params)
          
          # Business rule: race must be active
          race = yield race_repository.find(validated[:race_id])
          yield ensure_race_active(race)
          
          # Find or create incident
          incident = yield find_or_create_incident(validated)
          
          # Create report
          report_attrs = validated.merge(
            user_id: current_user_id,
            incident_id: incident.id
          )
          
          report = yield report_repository.create(report_attrs)
          
          # Side effect (explicit)
          BroadcastReportJob.perform_later(report.id)
          
          Success(report)
        end

        private

        def validate(params)
          contract = Domain::Contracts::ReportContract.new
          result = contract.call(params)
          
          result.success? ? Success(result.to_h) : Failure([:validation_failed, result.errors])
        end

        def ensure_race_active(race)
          race.active? ? Success(race) : Failure([:race_not_active, race.id])
        end

        def find_or_create_incident(validated)
          if validated[:incident_id]
            incident_repository.find(validated[:incident_id])
          else
            incident_repository.create(
              race_id: validated[:race_id],
              status: "unofficial",
              decision: "pending"
            )
          end
        end
      end
    end
  end
end

# Benefits:
# - All business logic explicit
# - Easy to test (no database needed for unit tests)
# - Composable with other commands
# - Clear error handling
# - Side effects are explicit
```

#### Infrastructure Record: `app/infrastructure/persistence/records/report_record.rb`

```ruby
module Infrastructure
  module Persistence
    module Records
      class ReportRecord < ApplicationRecord
        self.table_name = "reports"

        belongs_to :race_record, foreign_key: "race_id"
        belongs_to :incident_record, foreign_key: "incident_id", optional: true
        belongs_to :user_record, foreign_key: "user_id"

        has_one_attached :video

        # NO validations (domain handles this)
        # NO callbacks (application layer handles this)
        # NO business logic

        scope :ordered, -> { order(created_at: :desc) }
        scope :by_bib, ->(bib) { where(bib_number: bib) }
      end
    end
  end
end

# Benefits:
# - Pure data mapper
# - No business logic
# - No hidden side effects
# - Easy to understand
# - Can be replaced (e.g., with ROM)
```

#### Infrastructure Repository: `app/infrastructure/persistence/repositories/report_repository.rb`

```ruby
module Infrastructure
  module Persistence
    module Repositories
      class ReportRepository
        include Dry::Monads[:result]

        def create(attributes)
          record = Records::ReportRecord.new(attributes)
          
          if record.save
            Success(to_entity(record))
          else
            Failure(record.errors.to_hash)
          end
        end

        def find(id)
          record = Records::ReportRecord.find_by(id: id)
          return Failure(:not_found) unless record

          Success(to_entity(record))
        end

        private

        def to_entity(record)
          Domain::Entities::Report.new(
            id: record.id,
            client_uuid: record.client_uuid,
            race_id: record.race_id,
            incident_id: record.incident_id,
            user_id: record.user_id,
            bib_number: record.bib_number,
            description: record.description,
            athlete_name: record.athlete_name,
            video_url: record.video.attached? ? 
              Rails.application.routes.url_helpers.rails_blob_url(record.video) : nil,
            created_at: record.created_at
          )
        end
      end
    end
  end
end

# Benefits:
# - Explicit mapping between Record and Entity
# - Can change persistence layer without affecting domain
# - Returns Results for proper error handling
```

#### Web Controller: `app/web/controllers/api/reports_controller.rb`

```ruby
module Web
  module Controllers
    module Api
      class ReportsController < ApplicationController
        # Thin adapter - no business logic
        def create
          result = create_report_command.call(report_params, Current.user.id)

          handle_result(result) do |report|
            render json: {
              id: report.id,
              client_uuid: report.client_uuid,
              bib_number: report.bib_number,
              created_at: report.created_at
            }, status: :created
          end
        end

        private

        def create_report_command
          ApplicationContainer.resolve("commands.reports.create")
        end

        def report_params
          params.require(:report).permit(
            :client_uuid, :race_id, :bib_number, :description, :athlete_name
          ).to_h.symbolize_keys
        end
      end
    end
  end
end

# Benefits:
# - Thin controller (adapter only)
# - No business logic
# - Delegates to application layer
# - Easy to test
```

---

## Comparison Table

| Aspect | Traditional Rails | Hanami-Compatible |
|--------|-------------------|-------------------|
| **Business Logic** | Scattered (models, controllers, jobs) | Centralized in domain |
| **Validations** | Mixed with persistence (ActiveRecord) | Separate contracts (dry-validation) |
| **Side Effects** | Hidden in callbacks | Explicit in application layer |
| **Testing** | Requires database for most tests | Domain tests need no DB |
| **Framework Coupling** | Tightly coupled to Rails | Framework-agnostic core |
| **Migration Path** | Nearly impossible | Straightforward to Hanami |
| **Dependency Direction** | Circular (models ↔ controllers) | Unidirectional (downward) |
| **Reusability** | Hard (everything needs Rails) | Easy (domain is pure Ruby) |
| **Understanding** | Follow callbacks/hooks | Read top-to-bottom |
| **Testability** | Slow (integration tests) | Fast (unit tests) |

---

## File Count Comparison

### Traditional Rails (Same Feature)

```
app/
├── models/
│   └── report.rb                    (140 lines - god object)
├── controllers/
│   └── api/
│       └── reports_controller.rb    (30 lines)
└── jobs/
    └── broadcast_report_job.rb      (10 lines)

Total: 3 files, ~180 lines
Everything coupled to Rails
```

### Hanami-Compatible (Same Feature)

```
app/
├── domain/
│   ├── entities/
│   │   └── report.rb                (20 lines - pure logic)
│   └── contracts/
│       └── report_contract.rb       (15 lines - validation)
├── application/
│   └── commands/
│       └── reports/
│           └── create.rb            (40 lines - use case)
├── infrastructure/
│   ├── persistence/
│   │   ├── records/
│   │   │   └── report_record.rb     (15 lines - data mapper)
│   │   └── repositories/
│   │       └── report_repository.rb (30 lines - mapping)
│   └── jobs/
│       └── broadcast_report_job.rb  (10 lines)
└── web/
    └── controllers/
        └── api/
            └── reports_controller.rb (20 lines - thin adapter)

Total: 8 files, ~150 lines
Domain/Application are framework-agnostic
```

**More files, but:**
- Each file has single responsibility
- Business logic is isolated
- Easy to test independently
- Can migrate to Hanami
- Explicit dependencies

---

## Testing Comparison

### Traditional Rails

```ruby
# spec/models/report_spec.rb
RSpec.describe Report, type: :model do
  # Requires database for EVERY test
  it "validates bib number" do
    report = build(:report, bib_number: nil)
    expect(report.valid?).to be false
  end
  
  # Tests tightly coupled to ActiveRecord
  it "creates incident if needed" do
    report = create(:report, incident_id: nil)
    expect(report.incident).to be_present  # Database hit
  end
end

# Slow: ~200ms per test (database transactions)
```

### Hanami-Compatible

```ruby
# spec/domain/entities/report_spec.rb
RSpec.describe Domain::Entities::Report do
  # NO DATABASE - Pure Ruby
  it "displays athlete name" do
    report = described_class.new(
      race_id: 1,
      bib_number: 42,
      description: "Test",
      athlete_name: "John Doe"
    )
    
    expect(report.athlete_display_name).to eq("John Doe")
  end
end

# Fast: ~2ms per test (no I/O)

# spec/application/commands/reports/create_spec.rb
RSpec.describe Application::Commands::Reports::Create do
  # Integration test WITH database
  it "creates report and incident" do
    result = command.call(params, user_id)
    expect(result).to be_success
  end
end

# Moderate: ~50ms per test (only when needed)
```

**Result:**
- Traditional Rails: All tests slow (200ms+)
- Hanami-Compatible: 90% tests fast (2-5ms), 10% integration (50ms)

---

## Migration Path Comparison

### Traditional Rails → Hanami

**Difficulty**: Nearly impossible

```
❌ Must rewrite EVERYTHING
❌ All business logic in ActiveRecord models
❌ Callbacks everywhere
❌ Controllers have logic
❌ Tightly coupled to Rails
❌ Estimated time: 6-12 months
```

### Hanami-Compatible → Hanami

**Difficulty**: Straightforward

```
✅ Domain: Copy as-is (0 changes)
✅ Application: Copy as-is (0 changes)
✅ Infrastructure: Swap ActiveRecord for ROM (1 week)
✅ Web: Mechanical rewrite (2 weeks)
✅ Estimated time: 1-2 weeks
```

---

## When to Use Each Approach

### Use Traditional Rails When:

- Small CRUD app (<10 models)
- Short-lived project (< 1 year)
- Team unfamiliar with dry-rb
- Rapid prototyping
- No plans to migrate frameworks

### Use Hanami-Compatible When:

- Complex business logic
- Long-term project (3+ years)
- Need to migrate to Hanami later
- Team values architecture
- High test coverage important
- Multiple interfaces (web, mobile, API)
- **Turbo Native apps** (iOS/Android need stable backend)

---

## ISMF Race Logger: Why Hanami-Compatible?

### Requirements that drove decision:

1. **Complex Business Rules**
   - Incident status state machine
   - Decision workflows
   - Authorization rules
   - Merging incidents

2. **Multiple Interfaces**
   - FOP devices (tablets)
   - Desktop admin interface
   - Turbo Native iOS/Android apps
   - Future API for external systems

3. **Long-term Project**
   - Used for years (10+ years expected)
   - Will outlive current frameworks
   - Need to migrate to better frameworks as they emerge

4. **Performance**
   - FOP devices need <100ms response
   - Domain logic must be fast (no DB for calculations)
   - Background processing for heavy operations

5. **Testability**
   - Complex logic needs thorough testing
   - Fast test suite (1000+ tests in <10 seconds)
   - Confidence in refactoring

6. **Future-Proofing**
   - Hanami 2 offers better performance
   - ROM is faster than ActiveRecord
   - Architecture supports mobile apps during migration

### Conclusion

**For ISMF Race Logger, Hanami-compatible architecture is the right choice because:**

✅ Complex business logic isolated in domain  
✅ Multiple interfaces supported  
✅ Fast test suite  
✅ Easy migration to Hanami when ready  
✅ Turbo Native apps won't break during migration  
✅ Long-term maintainability  

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Architecture Decision Record