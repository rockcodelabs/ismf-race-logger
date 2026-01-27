# Hanami 2 Migration Guide (Future)

## Overview

This document provides a step-by-step guide for **creating a new Hanami 2 application** based on the ISMF Race Logger Rails app. Because the Rails application was architected with Hanami compatibility from day one, creating the Hanami version should be straightforward.

**IMPORTANT**: This is NOT about installing Hanami inside the Rails app. This is about creating a completely separate Hanami 2 project in the future when ready to migrate.

## Expected Effort

| Layer          | Migration Effort | Changes Required                    |
|----------------|------------------|-------------------------------------|
| Domain         | **0 hours**      | Copy as-is (no changes)             |
| Application    | **0 hours**      | Copy as-is (no changes)             |
| Infrastructure | **16-24 hours**  | Replace ActiveRecord with ROM       |
| Web            | **24-40 hours**  | Rewrite controllers → actions       |
| Configuration  | **8-16 hours**   | Boot files, routes, providers       |
| Testing        | **8-16 hours**   | Update test setup (specs unchanged) |

**Total Estimated Time**: 1-2 weeks

## Prerequisites

### Before You Start

**Current State**: Rails 8.1 app with Hanami-compatible architecture (using only dry-rb gems)

**Migration Goal**: Create NEW Hanami 2 app that replaces Rails app

**Deployment Strategy**: Blue-green deployment (run both, switch DNS)

### Knowledge Requirements

- Hanami 2.x architecture
- ROM (Ruby Object Mapper)
- Hanami routing and actions
- dry-rb ecosystem (already used in Rails app)

### Tools

Install Hanami CLI:
```bash
gem install hanami --version "~> 2.1"
```

**Note**: Do NOT install Hanami in the Rails app. Create a separate project.

## Migration Steps

### Phase 1: Create New Hanami Project

**IMPORTANT**: This is a NEW project, not a conversion of the Rails app.

#### Step 1.1: Generate New Hanami Application

In a **separate directory**, create the Hanami app:

```bash
# Outside the Rails project
cd ~/projects
hanami new ismf-race-logger-hanami --database=postgresql
cd ismf-race-logger-hanami
```

You now have two separate projects:
- `ismf-race-logger/` (Rails + dry-rb)
- `ismf-race-logger-hanami/` (Hanami)

#### Step 1.2: Configure Database

Edit `config/database.rb`:

```ruby
module ISMFRaceLogger
  class Database
    def self.configure(config)
      config.gateway(:default) do |gw|
        gw.adapter(:sql, ENV.fetch("DATABASE_URL"))
        gw.plugin(:pagination)
      end
    end
  end
end
```

Update `.env`:

```bash
DATABASE_URL=postgres://ismf_user:password@localhost/ismf_race_logger_development
```

---

### Phase 2: Copy Domain Layer (Zero Changes)

#### Step 2.1: Copy Domain Directory from Rails App

```bash
# From Hanami project root
cp -r ../ismf-race-logger/app/domain ./app/domain
```

That's it! Domain code is framework-agnostic and requires ZERO changes.

**Why this works:**
- Domain layer uses only dry-rb (no Rails)
- No ActiveRecord dependencies
- Pure Ruby business logic
- Already tested in Rails app

#### Step 2.2: Verify Domain Tests

```bash
bundle exec rspec spec/domain
```

Tests should pass without modification.

---

### Phase 3: Copy Application Layer (Zero Changes)

#### Step 3.1: Copy Application Directory from Rails App

```bash
# From Hanami project root
cp -r ../ismf-race-logger/app/application ./app/application
```

Again, ZERO changes needed!

**Why this works:**
- Application layer uses only dry-rb
- Accesses infrastructure through repositories (interface)
- No Rails-specific code

#### Step 3.2: Update Container Registration

Edit `config/providers/application.rb`:

```ruby
Hanami.app.register_provider :application do
  prepare do
    # Register commands
    register "commands.reports.create", Application::Commands::Reports::Create.new
    register "commands.reports.attach_video", Application::Commands::Reports::AttachVideo.new
    register "commands.incidents.merge", Application::Commands::Incidents::Merge.new
    register "commands.incidents.officialize", Application::Commands::Incidents::Officialize.new
    register "commands.incidents.apply_penalty", Application::Commands::Incidents::ApplyPenalty.new
    
    # Register queries
    register "queries.reports.by_race", Application::Queries::Reports::ByRace.new
    register "queries.incidents.pending_decision", Application::Queries::Incidents::PendingDecision.new
  end
end
```

Update dry-auto_inject imports:

```ruby
# Before (Rails)
Import = Dry::AutoInject(ApplicationContainer)

# After (Hanami)
Import = Hanami.app["deps"]
```

#### Step 3.3: Verify Application Tests

```bash
bundle exec rspec spec/application
```

Tests should pass with minimal changes to test setup.

---

### Phase 4: Rewrite Infrastructure Layer (Replace ActiveRecord with ROM)

**This is the only layer that needs rewriting** because we're replacing Rails/ActiveRecord with Hanami/ROM.

#### Step 4.1: Define ROM Relations

Create `app/infrastructure/persistence/relations/reports.rb`:

```ruby
module Infrastructure
  module Persistence
    module Relations
      class Reports < ROM::Relation[:sql]
        schema(:reports, infer: true) do
          associations do
            belongs_to :race
            belongs_to :incident
            belongs_to :user
          end
        end

        auto_struct true

        def ordered
          order { created_at.desc }
        end

        def by_bib(bib_number)
          where(bib_number: bib_number)
        end

        def by_race(race_id)
          where(race_id: race_id)
        end

        def recent(limit = 50)
          ordered.limit(limit)
        end
      end
    end
  end
end
```

Create `app/infrastructure/persistence/relations/incidents.rb`:

```ruby
module Infrastructure
  module Persistence
    module Relations
      class Incidents < ROM::Relation[:sql]
        schema(:incidents, infer: true) do
          associations do
            belongs_to :race
            has_many :reports
          end
        end

        auto_struct true

        def ordered
          order { created_at.desc }
        end

        def unofficial
          where(status: 0)
        end

        def official
          where(status: 1)
        end

        def pending_decision
          where(decision: 0)
        end

        def by_race(race_id)
          where(race_id: race_id)
        end
      end
    end
  end
end
```

#### Step 4.2: Rewrite Repositories for ROM

Update `app/infrastructure/persistence/repositories/report_repository.rb`:

```ruby
require "dry/monads"

module Infrastructure
  module Persistence
    module Repositories
      class ReportRepository
        include Dry::Monads[:result]
        include Hanami::Deps["persistence.rom"]

        def find(id)
          report = rom.relations[:reports].by_pk(id).one
          return Failure(:not_found) unless report

          Success(to_entity(report))
        end

        def create(attributes)
          report = rom.relations[:reports].changeset(:create, attributes).commit
          Success(to_entity(report))
        rescue ROM::SQL::UniqueConstraintViolationError => e
          Failure([:duplicate, e.message])
        end

        def by_race(race_id)
          reports = rom.relations[:reports]
            .by_race(race_id)
            .ordered
            .to_a

          Success(reports.map { |r| to_entity(r) })
        end

        def by_bib_number(race_id, bib_number)
          reports = rom.relations[:reports]
            .by_race(race_id)
            .by_bib(bib_number)
            .ordered
            .to_a

          Success(reports.map { |r| to_entity(r) })
        end

        def recent(limit: 50)
          reports = rom.relations[:reports]
            .recent(limit)
            .to_a

          Success(reports.map { |r| to_entity(r) })
        end

        private

        def to_entity(report)
          Domain::Entities::Report.new(
            id: report.id,
            client_uuid: report.client_uuid,
            race_id: report.race_id,
            incident_id: report.incident_id,
            user_id: report.user_id,
            bib_number: report.bib_number,
            race_location_id: report.race_location_id,
            athlete_name: report.athlete_name,
            description: report.description,
            video_url: report.video_url,
            created_at: report.created_at,
            updated_at: report.updated_at
          )
        end
      end
    end
  end
end
```

Update `app/infrastructure/persistence/repositories/incident_repository.rb`:

```ruby
require "dry/monads"

module Infrastructure
  module Persistence
    module Repositories
      class IncidentRepository
        include Dry::Monads[:result]
        include Hanami::Deps["persistence.rom"]

        def find(id)
          incident = rom.relations[:incidents].by_pk(id).one
          return Failure(:not_found) unless incident

          Success(to_entity(incident))
        end

        def create(attributes)
          incident = rom.relations[:incidents].changeset(:create, attributes).commit
          Success(to_entity(incident))
        end

        def update(id, attributes)
          incident = rom.relations[:incidents]
            .by_pk(id)
            .changeset(:update, attributes)
            .commit

          Success(to_entity(incident))
        rescue ROM::TupleCountMismatchError
          Failure(:not_found)
        end

        def by_race(race_id)
          incidents = rom.relations[:incidents]
            .by_race(race_id)
            .ordered
            .to_a

          Success(incidents.map { |i| to_entity(i) })
        end

        def pending_decisions(race_id)
          incidents = rom.relations[:incidents]
            .official
            .pending_decision
            .by_race(race_id)
            .ordered
            .to_a

          Success(incidents.map { |i| to_entity(i) })
        end

        def merge_incidents(target_id, source_ids)
          rom.gateways[:default].connection.transaction do
            # Update reports to point to target
            rom.relations[:reports]
              .where(incident_id: source_ids)
              .changeset(:update, incident_id: target_id)
              .commit

            # Delete source incidents
            rom.relations[:incidents]
              .where(id: source_ids)
              .command(:delete)
              .call

            # Fetch target
            target = rom.relations[:incidents].by_pk(target_id).one
            Success(to_entity(target))
          end
        rescue => e
          Failure(e.message)
        end

        private

        def to_entity(incident)
          Domain::Entities::Incident.new(
            id: incident.id,
            race_id: incident.race_id,
            race_location_id: incident.race_location_id,
            status: map_status(incident.status),
            decision: map_decision(incident.decision),
            officialized_by_user_id: incident.officialized_by_user_id,
            decided_by_user_id: incident.decided_by_user_id,
            officialized_at: incident.officialized_at,
            decided_at: incident.decided_at,
            decision_notes: incident.decision_notes,
            created_at: incident.created_at,
            updated_at: incident.updated_at
          )
        end

        def map_status(status_int)
          { 0 => "unofficial", 1 => "official" }[status_int]
        end

        def map_decision(decision_int)
          { 
            0 => "pending", 
            1 => "penalty_applied", 
            2 => "rejected", 
            3 => "no_action" 
          }[decision_int]
        end
      end
    end
  end
end
```

#### Step 4.3: Register ROM Provider

Create `config/providers/persistence.rb`:

```ruby
Hanami.app.register_provider :persistence do
  prepare do
    require "rom"
    require "rom-sql"

    config = ROM::Configuration.new(:sql, target["settings"].database_url)

    # Register relations
    config.register_relation(Infrastructure::Persistence::Relations::Reports)
    config.register_relation(Infrastructure::Persistence::Relations::Incidents)
    config.register_relation(Infrastructure::Persistence::Relations::Races)
    config.register_relation(Infrastructure::Persistence::Relations::Users)

    register "rom_config", config
  end

  start do
    config = target["rom_config"]
    register "rom", ROM.container(config)
  end
end
```

#### Step 4.4: Migrate Database Schema

Copy migrations:

```bash
cp -r ../ismf-race-logger/db/migrate ./db/migrate
```

Run migrations:

```bash
hanami db migrate
```

#### Step 4.5: Register Repositories

Update `config/providers/repositories.rb`:

```ruby
Hanami.app.register_provider :repositories do
  prepare do
    require "infrastructure/persistence/repositories/report_repository"
    require "infrastructure/persistence/repositories/incident_repository"
    require "infrastructure/persistence/repositories/race_repository"
    require "infrastructure/persistence/repositories/user_repository"

    register "repositories.report", Infrastructure::Persistence::Repositories::ReportRepository.new
    register "repositories.incident", Infrastructure::Persistence::Repositories::IncidentRepository.new
    register "repositories.race", Infrastructure::Persistence::Repositories::RaceRepository.new
    register "repositories.user", Infrastructure::Persistence::Repositories::UserRepository.new
  end
end
```

---

### Phase 5: Migrate Web Layer (Controllers → Actions)

#### Step 5.1: Convert Controllers to Actions

**Before (Rails Controller)**:

```ruby
# app/web/controllers/api/reports_controller.rb
class Api::ReportsController < ApplicationController
  def create
    result = create_report_command.call(report_params, Current.user.id)
    
    handle_result(result) do |report|
      render json: { id: report.id, bib_number: report.bib_number }, status: :created
    end
  end
end
```

**After (Hanami Action)**:

```ruby
# slices/api/actions/reports/create.rb
module API
  module Actions
    module Reports
      class Create < API::Action
        include Deps[
          "commands.reports.create",
          "services.current_user"
        ]

        params do
          required(:client_uuid).filled(:string)
          required(:race_id).filled(:integer)
          required(:bib_number).filled(:integer)
          required(:description).filled(:string)
        end

        def handle(request, response)
          halt 422, { errors: request.params.errors }.to_json unless request.params.valid?

          current_user = services_current_user.call(request)
          halt 401, { error: "Unauthorized" }.to_json unless current_user

          result = commands_reports_create.call(request.params.to_h, current_user.id)

          result.either(
            ->(report) {
              response.status = 201
              response.format = :json
              response.body = {
                id: report.id,
                client_uuid: report.client_uuid,
                bib_number: report.bib_number,
                created_at: report.created_at
              }.to_json
            },
            ->(error) {
              response.status = 422
              response.format = :json
              response.body = { error: error }.to_json
            }
          )
        end
      end
    end
  end
end
```

#### Step 5.2: Define Routes

**Before (Rails Routes)**:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    resources :reports, only: [:create]
  end
  
  namespace :admin do
    resources :incidents do
      member do
        post :officialize
        post :apply_penalty
        post :reject
      end
      
      collection do
        post :merge
      end
    end
  end
end
```

**After (Hanami Routes)**:

```ruby
# config/routes.rb
module ISMFRaceLogger
  class Routes < Hanami::Routes
    slice :api, at: "/api" do
      post "/reports", to: "reports.create"
      post "/reports/:id/video", to: "reports.attach_video"
    end

    slice :admin, at: "/admin" do
      get "/incidents", to: "incidents.index"
      get "/incidents/:id", to: "incidents.show"
      post "/incidents/:id/officialize", to: "incidents.officialize"
      post "/incidents/:id/apply_penalty", to: "incidents.apply_penalty"
      post "/incidents/:id/reject", to: "incidents.reject"
      post "/incidents/merge", to: "incidents.merge"
    end

    root to: "home.index"
  end
end
```

#### Step 5.3: Migrate Views

Hanami uses ERB templates similarly to Rails.

**Before (Rails View)**:

```erb
<!-- app/web/views/admin/incidents/index.html.erb -->
<h1>Incidents</h1>

<% @incidents.each do |incident| %>
  <div class="incident">
    <%= incident.id %> - <%= incident.status %>
  </div>
<% end %>
```

**After (Hanami View)**:

```erb
<!-- slices/admin/templates/incidents/index.html.erb -->
<h1>Incidents</h1>

<% incidents.each do |incident| %>
  <div class="incident">
    <%= incident.id %> - <%= incident.status %>
  </div>
<% end %>
```

With corresponding view:

```ruby
# slices/admin/views/incidents/index.rb
module Admin
  module Views
    module Incidents
      class Index < Admin::View
        include Deps["queries.incidents.pending_decision"]

        expose :incidents do |race_id:|
          queries_incidents_pending_decision.call(race_id).value_or([])
        end
      end
    end
  end
end
```

---

### Phase 6: Migrate Background Jobs

#### Step 6.1: Replace ActiveJob with Hanami Background

**Before (ActiveJob)**:

```ruby
# app/infrastructure/jobs/process_video_job.rb
class ProcessVideoJob < ApplicationJob
  def perform(report_id)
    # Processing logic
  end
end
```

**After (Hanami Background)**:

```ruby
# app/jobs/process_video.rb
module Jobs
  class ProcessVideo < Hanami::Job
    include Deps["repositories.report"]

    def call(report_id:)
      report = repositories_report.find(report_id).value_or { return }
      
      # Processing logic
    end
  end
end
```

Enqueue:

```ruby
# Before
ProcessVideoJob.perform_later(report_id)

# After
Jobs::ProcessVideo.perform_async(report_id: report_id)
```

---

### Phase 7: Testing Migration

#### Step 7.1: Update Test Setup

**Before (Rails)**:

```ruby
# spec/rails_helper.rb
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rspec/rails'

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
```

**After (Hanami)**:

```ruby
# spec/spec_helper.rb
require "hanami/prepare"

RSpec.configure do |config|
  config.before(:suite) do
    Hanami.app.prepare(:persistence)
  end

  config.around(:each, type: :database) do |example|
    Hanami.app["persistence.rom"].connection.transaction(rollback: :always) do
      example.run
    end
  end
end
```

#### Step 7.2: Test Migration Verification

Domain tests (unchanged):

```bash
bundle exec rspec spec/domain
```

Application tests (minimal changes):

```bash
bundle exec rspec spec/application
```

Integration tests (update action calls):

```bash
bundle exec rspec spec/slices
```

---

### Phase 8: Configuration & Deployment

#### Step 8.1: Environment Variables

Update `.env`:

```bash
# Before (Rails)
DATABASE_URL=postgres://...
RAILS_ENV=production
SECRET_KEY_BASE=...

# After (Hanami)
DATABASE_URL=postgres://...
HANAMI_ENV=production
SESSION_SECRET=...
```

#### Step 8.2: Update Dockerfile

```dockerfile
# Dockerfile
FROM ruby:3.4.8-alpine

# Install dependencies
RUN apk add --no-cache \
  build-base \
  postgresql-dev \
  nodejs \
  yarn

WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy application
COPY . .

# Precompile assets
RUN hanami assets compile

# Expose port
EXPOSE 2300

# Start server
CMD ["hanami", "server", "-p", "2300"]
```

#### Step 8.3: Update Kamal Configuration

```yaml
# config/deploy.yml
service: ismf-race-logger-hanami

image: regedarek/ismf-race-logger-hanami

servers:
  web:
    hosts:
      - pi5main.local
    options:
      network: ismf-network

env:
  clear:
    HANAMI_ENV: production
    DATABASE_URL: postgres://ismf_user@ismf-postgres/ismf_race_logger_production
  secret:
    - SESSION_SECRET

healthcheck:
  path: /up
  interval: 10s
```

---

## Validation Checklist

After creating Hanami app, verify:

### Functionality
- [ ] All domain tests pass unchanged
- [ ] All application tests pass with minimal changes
- [ ] Repository tests pass with ROM
- [ ] Action specs pass (formerly controller specs)
- [ ] Authentication works
- [ ] Authorization works
- [ ] Background jobs execute
- [ ] Real-time features work
- [ ] File uploads work
- [ ] Database queries are performant

### Integration
- [ ] Turbo Native apps can connect to Hanami backend
- [ ] API endpoints match Rails app
- [ ] WebSocket channels compatible

### Deployment
- [ ] Production deployment to staging succeeds
- [ ] Database migration from Rails schema
- [ ] All Rails data accessible in Hanami
- [ ] Performance meets or exceeds Rails app

---

## Deployment Strategy

### Blue-Green Deployment (Recommended)

1. **Keep Rails app running** at `race-logger.ismf-ski.com`
2. **Deploy Hanami app** to `hanami.race-logger.ismf-ski.com`
3. **Run both in parallel** for 1-2 weeks
4. **Test Hanami thoroughly** with real users on staging URL
5. **Compare metrics** (performance, stability, errors)
6. **Switch DNS** when confident (instant rollback if needed)
7. **Keep Rails running** for 1 week as backup
8. **Decommission Rails** when Hanami proven stable

### Rollback Plan

If issues found:
- **Instant rollback**: Switch DNS back to Rails (30 seconds)
- Rails app still running, no data loss
- Investigate issues, fix, redeploy Hanami
- Try again when ready

### Database Strategy

**Option A: Shared Database** (Easier)
- Both apps use same PostgreSQL database
- No data migration needed
- Instant switch

**Option B: Separate Databases** (Safer)
- Replicate data to Hanami database
- Test migration thoroughly
- Switch when data sync verified

---

## Benefits After Migration to Hanami

### Performance
1. **Faster Queries** - ROM is 2-3x faster than ActiveRecord
2. **Lower Memory** - Hanami uses ~50% less memory than Rails
3. **Faster Boot** - Application starts in <2 seconds

### Architecture
4. **Explicit Dependencies** - Even better DI with Hanami
5. **Cleaner Structure** - Slices enforce boundaries natively
6. **Type Safety** - dry-rb contracts everywhere (already have this)

### Maintenance
7. **Simpler Codebase** - Less framework magic
8. **Better Errors** - Clear stack traces
9. **Long-term Viability** - Modern framework, active development

### Business Value
10. **Lower Costs** - Reduced server resources needed
11. **Faster Features** - Cleaner code = faster development
12. **Future-Proof** - Not tied to Rails release cycle

---

## Common Issues & Solutions

### Issue: ROM Associations

**Problem**: ROM associations work differently from ActiveRecord.

**Solution**:
```ruby
# Eager loading in ROM
rom.relations[:reports]
  .combine(:incident)
  .combine(:user)
  .to_a
```

### Issue: Validations

**Problem**: ROM doesn't have built-in validations.

**Solution**: We already use dry-validation in domain, so no changes needed!

### Issue: Callbacks

**Problem**: No callbacks in ROM.

**Solution**: This is a GOOD thing! All side effects are explicit in application layer.

---

## Resources

- [Hanami 2 Documentation](https://guides.hanamirb.org/v2.1/)
- [ROM Documentation](https://rom-rb.org/learn/)
- [dry-rb Documentation](https://dry-rb.org/)
- [Hanami Migration Examples](https://github.com/hanami/hanami/tree/main/examples)

---

---

## Summary

### Key Points

✅ **Rails app stays pure** - No Hanami gem installed  
✅ **Domain & Application copy as-is** - Zero changes  
✅ **Infrastructure rewrite only** - ActiveRecord → ROM  
✅ **Web layer mechanical rewrite** - Controllers → Actions  
✅ **Parallel deployment** - No downtime, instant rollback  
✅ **1-2 week effort** - When ready to migrate  

### Current Status

**Today**: Rails 8.1 with Hanami-compatible architecture using dry-rb  
**Future**: Option to migrate to Hanami 2 when business case justifies  
**Protection**: Architecture ensures migration is low-risk and straightforward  

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Future Migration Guide (Not Current Implementation)  
**Note**: Do NOT install Hanami in Rails app