# Getting Started with Hanami-Compatible Architecture

## Quick Start Guide

This guide helps you understand and work with the ISMF Race Logger's Hanami-compatible architecture. Whether you're adding features, fixing bugs, or reviewing code, this document will help you navigate the layered structure.

## Architecture at a Glance

```
┌──────────────────────────────────────────────────────────┐
│  WEB (app/web)                                           │
│  Controllers receive HTTP, call application layer        │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│  APPLICATION (app/application)                           │
│  Commands & Queries orchestrate business logic           │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│  DOMAIN (app/domain)                                     │
│  Pure business logic - no framework code                 │
└──────────────────────────────────────────────────────────┘
                          ↑
┌──────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE (app/infrastructure)                     │
│  Database, jobs, mailers - all the I/O                  │
└──────────────────────────────────────────────────────────┘
```

## Rule #1: Dependencies Flow Downward

- Web can use Application and Domain
- Application can use Domain only
- Infrastructure can read Domain (for mapping)
- Domain depends on NOTHING

**This is enforced by Packwerk** - violations will fail CI/CD.

---

## Common Tasks

### Task: Add a New Feature

Let's say you need to add a feature: "Flag an incident as urgent".

#### Step 1: Define Business Logic (Domain)

**File**: `app/domain/entities/incident.rb`

```ruby
module Domain
  module Entities
    class Incident < Dry::Struct
      # ... existing attributes ...
      attribute :urgent, Types::Bool.default(false)

      def mark_as_urgent!
        new(urgent: true)
      end

      def urgent?
        urgent
      end
    end
  end
end
```

**Test**: `spec/domain/entities/incident_spec.rb`

```ruby
RSpec.describe Domain::Entities::Incident do
  describe "#urgent?" do
    it "returns true when marked urgent" do
      incident = described_class.new(
        race_id: 1,
        status: "official",
        decision: "pending",
        urgent: true
      )

      expect(incident.urgent?).to be true
    end
  end
end
```

#### Step 2: Create Use Case (Application)

**File**: `app/application/commands/incidents/mark_urgent.rb`

```ruby
require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Incidents
      class MarkUrgent
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.incident"]

        def call(incident_id, current_user)
          # Find incident
          incident = yield incident_repository.find(incident_id)
          
          # Authorize
          yield authorize(current_user)
          
          # Update
          updated = yield incident_repository.update(incident_id, { urgent: true })
          
          # Notify (async)
          NotifyUrgentIncidentJob.perform_later(updated.id)
          
          Success(updated)
        end

        private

        def authorize(user)
          user.admin? ? Success(user) : Failure([:unauthorized, "Admin required"])
        end
      end
    end
  end
end
```

**Test**: `spec/application/commands/incidents/mark_urgent_spec.rb`

```ruby
RSpec.describe Application::Commands::Incidents::MarkUrgent do
  let(:command) { described_class.new }
  let(:admin_user) { create(:user_record, admin: true) }
  let(:incident) { create(:incident_record) }

  it "marks incident as urgent" do
    user_entity = Domain::Entities::User.new(
      id: admin_user.id,
      email: admin_user.email,
      name: admin_user.name,
      admin: true
    )

    result = command.call(incident.id, user_entity)

    expect(result).to be_success
    expect(result.value!.urgent).to be true
  end
end
```

#### Step 3: Add Repository Method (Infrastructure)

**File**: `app/infrastructure/persistence/repositories/incident_repository.rb`

```ruby
# Add to existing repository:

def mark_urgent(incident_id)
  update(incident_id, { urgent: true })
end
```

#### Step 4: Create Controller Action (Web)

**File**: `app/web/controllers/admin/incidents_controller.rb`

```ruby
module Web
  module Controllers
    module Admin
      class IncidentsController < ApplicationController
        # ... existing actions ...

        def mark_urgent
          result = mark_urgent_command.call(params[:id], current_user_entity)

          handle_result(result) do |incident|
            respond_to do |format|
              format.html { redirect_to admin_incident_path(incident.id), notice: "Marked as urgent" }
              format.turbo_stream { 
                render turbo_stream: turbo_stream.replace(
                  "incident_#{incident.id}", 
                  partial: "incident", 
                  locals: { incident: incident }
                )
              }
            end
          end
        end

        private

        def mark_urgent_command
          ApplicationContainer.resolve("commands.incidents.mark_urgent")
        end
      end
    end
  end
end
```

#### Step 5: Register Command (Configuration)

**File**: `config/initializers/dry_container.rb`

```ruby
# Add to commands.incidents namespace:

register :mark_urgent do
  Application::Commands::Incidents::MarkUrgent.new
end
```

#### Step 6: Add Route

**File**: `config/routes.rb`

```ruby
namespace :admin do
  resources :incidents do
    member do
      post :mark_urgent  # Add this line
    end
  end
end
```

**Done!** Your feature is now fully implemented across all layers.

---

### Task: Query Data

Need to fetch data? Create a query in the application layer.

**File**: `app/application/queries/incidents/urgent_incidents.rb`

```ruby
require "dry/monads"

module Application
  module Queries
    module Incidents
      class UrgentIncidents
        include Dry::Monads[:result]
        include Import["repositories.incident"]

        def call(race_id)
          # Repository method fetches urgent incidents
          incident_repository.urgent_by_race(race_id)
        end
      end
    end
  end
end
```

**Use in controller**:

```ruby
def urgent
  result = urgent_incidents_query.call(params[:race_id])
  
  handle_result(result) do |incidents|
    render :urgent, locals: { incidents: incidents }
  end
end

private

def urgent_incidents_query
  ApplicationContainer.resolve("queries.incidents.urgent_incidents")
end
```

---

### Task: Add Background Job

Background jobs live in infrastructure.

**File**: `app/infrastructure/jobs/notify_urgent_incident_job.rb`

```ruby
class NotifyUrgentIncidentJob < ApplicationJob
  queue_as :urgent

  def perform(incident_id)
    # Fetch data from infrastructure
    incident_record = Infrastructure::Persistence::Records::IncidentRecord.find(incident_id)
    
    # Send notification (infrastructure concern)
    NotificationMailer.urgent_incident(incident_record).deliver_later
    
    # Broadcast to WebSocket
    Turbo::StreamsChannel.broadcast_update_to(
      "incidents",
      target: "incident_#{incident_id}",
      partial: "incidents/incident",
      locals: { incident: incident_record }
    )
  end
end
```

**Trigger from application layer**:

```ruby
# In command:
def call(incident_id, user)
  incident = yield incident_repository.update(incident_id, { urgent: true })
  
  # Trigger job
  NotifyUrgentIncidentJob.perform_later(incident.id)
  
  Success(incident)
end
```

---

## Understanding Each Layer

### Domain Layer: Pure Business Logic

**What goes here**:
- Entities (User, Report, Incident, Race)
- Value Objects (BibNumber, IncidentStatus)
- Contracts (validation rules)
- Domain Services (pure calculations)

**What NEVER goes here**:
- `Rails.*`
- `ActiveRecord`
- `ActiveJob`
- HTTP concerns
- Database queries

**Example - Good Domain Entity**:

```ruby
module Domain
  module Entities
    class Report < Dry::Struct
      attribute :id, Types::Integer.optional
      attribute :bib_number, Types::Integer
      attribute :description, Types::String

      def summary
        "Report for Bib ##{bib_number}"
      end
    end
  end
end
```

**Example - Bad Domain Entity**:

```ruby
# ❌ NEVER DO THIS
module Domain
  module Entities
    class Report < Dry::Struct
      def save
        ReportRecord.create!(attributes)  # ❌ Database access!
      end

      def video_url
        Rails.application.routes.url_helpers.blob_url(video)  # ❌ Rails!
      end
    end
  end
end
```

### Application Layer: Orchestration

**What goes here**:
- Commands (write operations)
- Queries (read operations)
- Transaction orchestration
- Calling multiple repositories
- Triggering background jobs

**What NEVER goes here**:
- HTTP request/response logic
- Direct database queries (use repositories)
- View rendering

**Example - Good Command**:

```ruby
module Application
  module Commands
    module Reports
      class Create
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.report", "repositories.incident"]

        def call(params, user_id)
          validated = yield validate(params)
          incident = yield find_or_create_incident(validated)
          report = yield report_repository.create(validated.merge(user_id: user_id))
          
          BroadcastReportJob.perform_later(report.id)
          
          Success(report)
        end
      end
    end
  end
end
```

### Infrastructure Layer: I/O Adapters

**What goes here**:
- ActiveRecord models (suffixed with `Record`)
- Repositories (map Records → Entities)
- Background jobs
- Mailers
- External API clients

**What NEVER goes here**:
- Business logic
- Validations (use domain contracts)
- Callbacks with business logic

**Example - Good Repository**:

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

        private

        def to_entity(record)
          Domain::Entities::Report.new(
            id: record.id,
            bib_number: record.bib_number,
            description: record.description
            # Map all attributes
          )
        end
      end
    end
  end
end
```

**Example - Good Record (No Logic)**:

```ruby
module Infrastructure
  module Persistence
    module Records
      class ReportRecord < ApplicationRecord
        self.table_name = "reports"

        belongs_to :race_record, foreign_key: "race_id"
        belongs_to :user_record, foreign_key: "user_id"

        has_one_attached :video

        # NO validations
        # NO callbacks
        # NO business logic

        scope :ordered, -> { order(created_at: :desc) }
        scope :by_bib, ->(bib) { where(bib_number: bib) }
      end
    end
  end
end
```

### Web Layer: HTTP Adapter

**What goes here**:
- Controllers (thin!)
- Views (ERB templates)
- ViewComponents
- Routes

**What NEVER goes here**:
- Business logic
- Direct database access
- Fat controllers

**Example - Good Controller (Thin)**:

```ruby
module Web
  module Controllers
    module Admin
      class IncidentsController < ApplicationController
        def index
          result = pending_incidents_query.call(params[:race_id])
          
          handle_result(result) do |incidents|
            render :index, locals: { incidents: incidents }
          end
        end

        private

        def pending_incidents_query
          ApplicationContainer.resolve("queries.incidents.pending_decision")
        end
      end
    end
  end
end
```

---

## Working with dry-monads

All application layer methods return `Result` objects.

### Success/Failure

```ruby
# Return success
Success(value)

# Return failure
Failure(error)
Failure([:error_type, details])
```

### Pattern Matching (Ruby 3+)

```ruby
result = command.call(params)

result.either(
  ->(value) { puts "Success: #{value}" },
  ->(error) { puts "Error: #{error}" }
)
```

### Do Notation (Early Return)

```ruby
include Dry::Monads::Do.for(:call)

def call(params)
  user = yield find_user(params[:user_id])      # Returns early if Failure
  report = yield create_report(params)          # Returns early if Failure
  
  Success([user, report])                       # Only reached if all succeed
end
```

### Unwrapping Values

```ruby
# Get value or raise
value = result.value!  # Raises if Failure

# Get value or default
value = result.value_or(default)
value = result.value_or { computed_default }

# Check status
result.success?  # => true/false
result.failure?  # => true/false
```

---

## Testing Strategy

### Domain Tests (Fast Unit Tests)

```ruby
# spec/domain/entities/incident_spec.rb
require "rails_helper"

RSpec.describe Domain::Entities::Incident do
  # No database, no Rails, pure Ruby
  it "determines if can officialize" do
    incident = described_class.new(
      race_id: 1,
      status: "unofficial",
      decision: "pending"
    )

    expect(incident.can_officialize?).to be true
  end
end
```

### Application Tests (Integration)

```ruby
# spec/application/commands/incidents/officialize_spec.rb
require "rails_helper"

RSpec.describe Application::Commands::Incidents::Officialize do
  let(:command) { described_class.new }
  let(:incident) { create(:incident_record, status: :unofficial) }
  let(:admin) { create(:user_record, admin: true) }

  it "officializes incident" do
    user_entity = Domain::Entities::User.new(
      id: admin.id,
      admin: true,
      # ... other attributes
    )

    result = command.call(incident.id, user_entity)

    expect(result).to be_success
    expect(result.value!.official?).to be true
  end
end
```

### Web Tests (Request Specs)

```ruby
# spec/web/controllers/admin/incidents_controller_spec.rb
require "rails_helper"

RSpec.describe Admin::IncidentsController, type: :request do
  let(:admin) { create(:user_record, admin: true) }
  let(:incident) { create(:incident_record) }

  before { sign_in(admin) }

  describe "POST /admin/incidents/:id/officialize" do
    it "officializes incident" do
      post officialize_admin_incident_path(incident)

      expect(response).to redirect_to(admin_incident_path(incident))
      expect(incident.reload.status).to eq("official")
    end
  end
end
```

---

## Debugging Tips

### Tip 1: Use Rails Console to Test Commands

```ruby
docker compose exec app bin/rails console

# Load repositories
report_repo = ApplicationContainer.resolve("repositories.report")

# Test repository
result = report_repo.find(1)
result.success?  # => true/false
result.value!    # => Domain::Entities::Report

# Test command
command = ApplicationContainer.resolve("commands.reports.create")
params = { race_id: 1, bib_number: 42, description: "Test" }
result = command.call(params, current_user_id: 1)
```

### Tip 2: Inspect Result Objects

```ruby
result = command.call(params)

# Check type
result.class  # => Dry::Monads::Result::Success or Dry::Monads::Result::Failure

# Inspect value
pp result.value!

# Inspect failure
result.failure  # Returns error details
```

### Tip 3: Check Packwerk Violations

```bash
# Check all boundaries
docker compose exec app bundle exec packwerk check

# Check specific package
docker compose exec app bundle exec packwerk check app/domain/

# Update cache after changes
docker compose exec app bundle exec packwerk update
```

---

## Common Mistakes

### Mistake 1: Mixing Entities and Records

```ruby
# ❌ BAD: Passing Record to domain
def calculate_penalty(report_record)
  # Domain shouldn't know about Records
end

# ✅ GOOD: Convert to Entity first
def calculate_penalty(report_entity)
  # Domain works with Entities
end
```

### Mistake 2: Business Logic in Controllers

```ruby
# ❌ BAD
class ReportsController < ApplicationController
  def create
    if params[:bib_number] > 9999
      render json: { error: "Invalid bib" }, status: 422
    else
      report = Report.create!(params)
      render json: report
    end
  end
end

# ✅ GOOD
class ReportsController < ApplicationController
  def create
    result = create_report_command.call(report_params, current_user.id)
    
    handle_result(result) do |report|
      render json: report, status: :created
    end
  end
end
```

### Mistake 3: Direct Database Access in Application

```ruby
# ❌ BAD
class CreateReport
  def call(params)
    record = ReportRecord.create!(params)
    Success(record)
  end
end

# ✅ GOOD
class CreateReport
  include Import["repositories.report"]
  
  def call(params)
    report_repository.create(params)
  end
end
```

---

## Quick Reference

### File Locations

| Component         | Location                                    |
|-------------------|---------------------------------------------|
| Entity            | `app/domain/entities/`                      |
| Value Object      | `app/domain/value_objects/`                 |
| Domain Contract   | `app/domain/contracts/`                     |
| Command           | `app/application/commands/`                 |
| Query             | `app/application/queries/`                  |
| Repository        | `app/infrastructure/persistence/repositories/` |
| Record            | `app/infrastructure/persistence/records/`   |
| Job               | `app/infrastructure/jobs/`                  |
| Controller        | `app/web/controllers/`                      |
| View              | `app/web/views/`                            |

### Common Commands

```bash
# Run tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Check architecture boundaries
docker compose exec app bundle exec packwerk check

# Rails console
docker compose exec app bin/rails console

# Database migrations
docker compose exec app bin/rails db:migrate

# Reset database
docker compose exec app bin/rails db:reset
```

---

## Further Reading

- [Hanami Architecture Implementation Plan](./hanami-architecture-implementation-plan.md)
- [Packwerk Boundaries](./packwerk-boundaries.md)
- [Hanami Migration Guide](./hanami-migration-guide.md)
- [dry-rb Documentation](https://dry-rb.org/)

---

**Need Help?**

If you're unsure where code should go, ask:
1. Does it contain business rules? → Domain
2. Does it orchestrate multiple operations? → Application
3. Does it touch the database/external APIs? → Infrastructure
4. Does it handle HTTP requests? → Web

When in doubt, put it in Application and refactor later.

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Active Development Guide