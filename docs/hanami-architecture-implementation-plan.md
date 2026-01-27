# ISMF Race Logger - Hanami-Compatible Architecture Implementation Plan

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Layer Responsibilities](#layer-responsibilities)
3. [Directory Structure](#directory-structure)
4. [Implementation Phases](#implementation-phases)
5. [Migration Path](#migration-path)
6. [Code Examples](#code-examples)
7. [Testing Strategy](#testing-strategy)
8. [Deployment Considerations](#deployment-considerations)

---

## Architecture Overview

This application is architected to be **Hanami-compatible from day one**, using Rails 8.1 as an adapter layer only. The goal is to enable migration to Hanami 2 with zero changes to domain and application layers.

### Core Principles

1. **Rails is an adapter** - Not the core of the application
2. **Business logic lives in dry-rb layers** - Framework-agnostic
3. **Dependencies flow downward only** - Enforced by Packwerk
4. **ActiveRecord is infrastructure** - Persistence is a detail
5. **Turbo Native support** - Mobile apps require no backend changes during migration

### Four-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  WEB LAYER (Rails Controllers, Views, Components)      │
│  - Thin adapters                                         │
│  - HTTP request/response handling                        │
│  - Turbo/Stimulus for interactivity                     │
└─────────────────────────────────────────────────────────┘
                          ↓ depends on
┌─────────────────────────────────────────────────────────┐
│  APPLICATION LAYER (Use Cases, Commands, Queries)       │
│  - Orchestrates domain + infrastructure                  │
│  - dry-monads for control flow                          │
│  - Dependency injection via dry-auto_inject             │
└─────────────────────────────────────────────────────────┘
                          ↓ depends on
┌─────────────────────────────────────────────────────────┐
│  DOMAIN LAYER (Entities, Value Objects, Contracts)      │
│  - Pure business logic                                   │
│  - dry-struct for entities                              │
│  - dry-validation for contracts                         │
│  - NO Rails, NO ActiveRecord, NO framework code         │
└─────────────────────────────────────────────────────────┘
                          ↑ used by
┌─────────────────────────────────────────────────────────┐
│  INFRASTRUCTURE LAYER (Repositories, Jobs, Mailers)     │
│  - ActiveRecord models (suffixed with "Record")         │
│  - External service adapters                            │
│  - Background jobs                                       │
│  - File storage                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

### 1. Domain Layer (`app/domain`)

**Purpose**: Pure business logic, framework-agnostic

**Allowed Dependencies**:
- dry-struct
- dry-types
- dry-validation
- dry-monads
- Standard Ruby

**FORBIDDEN**:
- Rails constants
- ActiveRecord
- ActiveSupport (except core_ext if unavoidable)
- Any persistence logic
- Any HTTP concerns

**Contains**:
- **Entities** - Business objects with identity (dry-struct)
- **Value Objects** - Immutable data without identity
- **Contracts** - Validation rules (dry-validation)
- **Domain Services** - Pure business logic operations
- **Types** - Custom dry-types definitions

**Example Structure**:
```
app/domain/
├── entities/
│   ├── report.rb
│   ├── incident.rb
│   ├── race.rb
│   └── athlete.rb
├── value_objects/
│   ├── bib_number.rb
│   ├── incident_status.rb
│   └── decision_type.rb
├── contracts/
│   ├── report_contract.rb
│   ├── incident_contract.rb
│   └── merge_incidents_contract.rb
├── services/
│   └── incident_decision_calculator.rb
└── types.rb
```

### 2. Application Layer (`app/application`)

**Purpose**: Use case orchestration, coordinates domain + infrastructure

**Allowed Dependencies**:
- app/domain
- app/infrastructure (via interfaces/dependency injection)
- dry-monads
- dry-transaction (optional)
- dry-auto_inject

**FORBIDDEN**:
- Direct Rails controller access
- Direct ActiveRecord queries (must go through repositories)
- View logic

**Contains**:
- **Commands** - Write operations (mutations)
- **Queries** - Read operations
- **Services** - Complex orchestration
- **Contracts** - Input validation for use cases

**Example Structure**:
```
app/application/
├── commands/
│   ├── reports/
│   │   ├── create.rb
│   │   └── attach_video.rb
│   └── incidents/
│       ├── merge.rb
│       ├── officialize.rb
│       ├── apply_penalty.rb
│       └── reject.rb
├── queries/
│   ├── reports/
│   │   ├── by_race.rb
│   │   └── recent.rb
│   └── incidents/
│       ├── pending_decision.rb
│       └── by_bib_number.rb
├── contracts/
│   ├── create_report_contract.rb
│   └── merge_incidents_contract.rb
└── container.rb
```

### 3. Infrastructure Layer (`app/infrastructure`)

**Purpose**: Framework adapters, persistence, external services

**Allowed Dependencies**:
- Rails
- ActiveRecord
- ActiveJob
- ActiveStorage
- app/domain (for mapping to entities)

**Contains**:
- **Records** - ActiveRecord models (suffixed with "Record")
- **Repositories** - Data access abstractions
- **Jobs** - Background processing
- **Mailers** - Email sending
- **Storage** - File handling
- **External Services** - API clients

**Example Structure**:
```
app/infrastructure/
├── persistence/
│   ├── records/
│   │   ├── report_record.rb
│   │   ├── incident_record.rb
│   │   ├── race_record.rb
│   │   ├── user_record.rb
│   │   └── session_record.rb
│   └── repositories/
│       ├── report_repository.rb
│       ├── incident_repository.rb
│       └── race_repository.rb
├── jobs/
│   ├── process_video_job.rb
│   └── broadcast_incident_job.rb
├── mailers/
│   └── notification_mailer.rb
└── storage/
    └── video_processor.rb
```

### 4. Web Layer (`app/web`)

**Purpose**: HTTP interface, thin controllers, views

**Allowed Dependencies**:
- app/application (primary)
- app/domain (for reading entities)
- Rails (ActionController, ActionView)
- Turbo/Stimulus

**FORBIDDEN**:
- app/infrastructure (direct access)
- Business logic in controllers
- Fat controllers

**Contains**:
- **Controllers** - Request/response handling
- **Views** - HTML templates
- **Components** - ViewComponent for reusable UI
- **Helpers** - View helpers only

**Example Structure**:
```
app/web/
├── controllers/
│   ├── concerns/
│   │   └── authentication.rb
│   ├── admin/
│   │   ├── incidents_controller.rb
│   │   └── reports_controller.rb
│   ├── api/
│   │   └── reports_controller.rb
│   ├── sessions_controller.rb
│   └── incidents_controller.rb
├── views/
│   ├── layouts/
│   │   ├── application.html.erb
│   │   ├── admin.html.erb
│   │   └── turbo_native.html.erb
│   ├── admin/
│   │   ├── incidents/
│   │   └── reports/
│   └── incidents/
│       ├── index.html.erb
│       └── show.html.erb
└── components/
    ├── fop/
    │   ├── button_component.rb
    │   └── incident_form_component.rb
    └── admin/
        └── incident_card_component.rb
```

---

## Directory Structure

### Complete Application Structure

```
ismf-race-logger/
├── app/
│   ├── domain/                          # Layer 1: Pure business logic
│   │   ├── entities/
│   │   ├── value_objects/
│   │   ├── contracts/
│   │   ├── services/
│   │   └── types.rb
│   │
│   ├── application/                     # Layer 2: Use cases
│   │   ├── commands/
│   │   ├── queries/
│   │   ├── contracts/
│   │   └── container.rb
│   │
│   ├── infrastructure/                  # Layer 3: Adapters
│   │   ├── persistence/
│   │   │   ├── records/
│   │   │   └── repositories/
│   │   ├── jobs/
│   │   ├── mailers/
│   │   └── storage/
│   │
│   └── web/                             # Layer 4: HTTP interface
│       ├── controllers/
│       ├── views/
│       └── components/
│
├── config/
│   └── initializers/
│       ├── dry_container.rb
│       └── packwerk.rb
│
├── package.yml                           # Packwerk root config
├── app/domain/package.yml
├── app/application/package.yml
├── app/infrastructure/package.yml
├── app/web/package.yml
│
├── spec/
│   ├── domain/                          # Unit tests (fast)
│   ├── application/                     # Integration tests
│   ├── infrastructure/                  # Repository tests
│   └── web/                             # Request specs
│
└── docs/
    ├── architecture/
    │   ├── hanami-migration-guide.md
    │   └── layer-dependencies.md
    └── hanami-architecture-implementation-plan.md (this file)
```

---

## Implementation Phases

### Phase 0: Foundation Setup

**Goal**: Install dry-rb ecosystem and Packwerk

#### Task 0.1: Add dry-rb Gems (NO Hanami!)

**IMPORTANT**: We do NOT install Hanami gem. We only use dry-rb gems to build a Hanami-compatible architecture within Rails.

Update `Gemfile`:

```ruby
# Domain layer - Framework-agnostic business logic
gem "dry-struct", "~> 1.6"
gem "dry-types", "~> 1.7"
gem "dry-validation", "~> 1.10"
gem "dry-monads", "~> 1.6"

# Application layer - Use case orchestration
gem "dry-auto_inject", "~> 1.0"
gem "dry-container", "~> 0.11"
gem "dry-transaction", "~> 0.15" # optional

# Architecture enforcement
gem "packwerk", "~> 3.2"

group :development do
  gem "packwerk-extensions", require: false
end

# NOTE: We do NOT install "hanami" gem
# This app uses Rails with Hanami-compatible architecture
# Migration to Hanami 2 happens later as a separate project
```

Run:
```bash
docker compose exec app bundle install
```

**Why no Hanami gem?**
- Hanami and Rails conflict when installed together
- We're building Hanami-*compatible* architecture, not running Hanami
- Migration to actual Hanami happens as a future separate deployment
- dry-rb gems work perfectly in Rails without Hanami

#### Task 0.2: Initialize Packwerk

```bash
docker compose exec app bundle exec packwerk init
```

Create package definitions:

**`package.yml`** (root):
```yaml
enforce_dependencies: true
enforce_privacy: true
```

**`app/domain/package.yml`**:
```yaml
enforce_dependencies: true
enforce_privacy: false

dependencies: []
```

**`app/application/package.yml`**:
```yaml
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/domain
```

**`app/infrastructure/package.yml`**:
```yaml
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/domain
```

**`app/web/package.yml`**:
```yaml
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/application
  - app/domain
```

#### Task 0.3: Configure dry-container

**`config/initializers/dry_container.rb`**:

```ruby
require "dry/container"
require "dry/auto_inject"

class ApplicationContainer
  extend Dry::Container::Mixin

  # Repositories will be registered here
  namespace :repositories do
  end
  
  # Commands will be registered here
  namespace :commands do
  end
  
  # Queries will be registered here
  namespace :queries do
  end
end

# Dependency injection
Import = Dry::AutoInject(ApplicationContainer)
```

#### Task 0.4: Create Domain Types

**`app/domain/types.rb`**:

```ruby
require "dry-types"

module Domain
  module Types
    include Dry.Types()

    # Common types
    Email = String.constrained(format: URI::MailTo::EMAIL_REGEXP)
    StrictString = Strict::String.constrained(min_size: 1)
    
    # Incident statuses
    IncidentStatus = Strict::String.enum("unofficial", "official")
    
    # Decision types
    DecisionType = Strict::String.enum(
      "pending",
      "penalty_applied", 
      "rejected",
      "no_action"
    )
    
    # Referee levels
    RefereeLevel = Strict::String.enum(
      "national_referee",
      "international_referee",
      "referee_manager",
      "var_operator"
    )
    
    # UUIDs
    UUID = String.constrained(format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
  end
end
```

---

### Phase 1: Domain Layer - Entities & Value Objects

**Goal**: Create framework-agnostic domain models

#### Task 1.1: Create Domain Entities

**`app/domain/entities/report.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Report < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::Integer.optional
      attribute :client_uuid, Types::UUID
      attribute :race_id, Types::Integer
      attribute :incident_id, Types::Integer.optional
      attribute :user_id, Types::Integer
      attribute :bib_number, Types::Coercible::Integer
      attribute :race_location_id, Types::Integer.optional
      attribute :athlete_name, Types::String.optional
      attribute :description, Types::String
      attribute :video_url, Types::String.optional
      attribute :created_at, Types::Params::DateTime.optional
      attribute :updated_at, Types::Params::DateTime.optional

      def has_video?
        !video_url.nil?
      end

      def athlete_display_name
        athlete_name || "Unknown Athlete"
      end
    end
  end
end
```

**`app/domain/entities/incident.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Incident < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::Integer.optional
      attribute :race_id, Types::Integer
      attribute :race_location_id, Types::Integer.optional
      attribute :status, Types::IncidentStatus
      attribute :decision, Types::DecisionType
      attribute :officialized_by_user_id, Types::Integer.optional
      attribute :decided_by_user_id, Types::Integer.optional
      attribute :officialized_at, Types::Params::DateTime.optional
      attribute :decided_at, Types::Params::DateTime.optional
      attribute :decision_notes, Types::String.optional
      attribute :created_at, Types::Params::DateTime.optional
      attribute :updated_at, Types::Params::DateTime.optional

      # Business logic methods
      def unofficial?
        status == "unofficial"
      end

      def official?
        status == "official"
      end

      def pending?
        decision == "pending"
      end

      def decided?
        !pending?
      end

      def can_officialize?
        unofficial?
      end

      def can_decide?
        official? && pending?
      end
    end
  end
end
```

**`app/domain/entities/race.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class Race < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::Integer.optional
      attribute :name, Types::String
      attribute :race_date, Types::Params::Date
      attribute :location, Types::String
      attribute :status, Types::String.enum("upcoming", "active", "completed")
      attribute :created_at, Types::Params::DateTime.optional
      attribute :updated_at, Types::Params::DateTime.optional

      def active?
        status == "active"
      end

      def completed?
        status == "completed"
      end
    end
  end
end
```

**`app/domain/entities/user.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module Entities
    class User < Dry::Struct
      transform_keys(&:to_sym)

      attribute :id, Types::Integer.optional
      attribute :email, Types::Email
      attribute :name, Types::String
      attribute :admin, Types::Bool
      attribute :referee_level, Types::RefereeLevel.optional
      attribute :created_at, Types::Params::DateTime.optional
      attribute :updated_at, Types::Params::DateTime.optional

      def admin?
        admin
      end

      def referee?
        !referee_level.nil?
      end

      def can_officialize?
        admin? || referee?
      end

      def can_decide?
        admin? || referee_level.in?(["referee_manager", "international_referee"])
      end
    end
  end
end
```

#### Task 1.2: Create Value Objects

**`app/domain/value_objects/bib_number.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module ValueObjects
    class BibNumber < Dry::Struct
      attribute :value, Types::Coercible::Integer.constrained(gteq: 1, lteq: 9999)

      def to_s
        value.to_s.rjust(4, "0")
      end

      def to_i
        value
      end
    end
  end
end
```

**`app/domain/value_objects/incident_status.rb`**:

```ruby
require "dry-struct"
require_relative "../types"

module Domain
  module ValueObjects
    class IncidentStatus < Dry::Struct
      attribute :value, Types::IncidentStatus

      UNOFFICIAL = new(value: "unofficial")
      OFFICIAL = new(value: "official")

      def unofficial?
        value == "unofficial"
      end

      def official?
        value == "official"
      end

      def can_transition_to?(new_status)
        case value
        when "unofficial" then new_status == "official"
        when "official" then false # Can't go back
        end
      end
    end
  end
end
```

#### Task 1.3: Create Domain Contracts

**`app/domain/contracts/report_contract.rb`**:

```ruby
require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class ReportContract < Dry::Validation::Contract
      params do
        required(:client_uuid).filled(Types::UUID)
        required(:race_id).filled(:integer)
        required(:user_id).filled(:integer)
        required(:bib_number).filled(:integer, gteq?: 1, lteq?: 9999)
        required(:description).filled(:string)
        optional(:race_location_id).maybe(:integer)
        optional(:athlete_name).maybe(:string)
        optional(:incident_id).maybe(:integer)
      end

      rule(:bib_number) do
        key.failure("must be between 1 and 9999") unless value.between?(1, 9999)
      end
    end
  end
end
```

**`app/domain/contracts/incident_contract.rb`**:

```ruby
require "dry/validation"
require_relative "../types"

module Domain
  module Contracts
    class IncidentContract < Dry::Validation::Contract
      params do
        required(:race_id).filled(:integer)
        required(:status).filled(Types::IncidentStatus)
        required(:decision).filled(Types::DecisionType)
        optional(:race_location_id).maybe(:integer)
        optional(:officialized_by_user_id).maybe(:integer)
        optional(:decided_by_user_id).maybe(:integer)
        optional(:decision_notes).maybe(:string)
      end

      rule(:decision, :decided_by_user_id) do
        if values[:decision] != "pending" && values[:decided_by_user_id].nil?
          key(:decided_by_user_id).failure("must be present when decision is not pending")
        end
      end
    end
  end
end
```

#### Task 1.4: Create Domain Services (Pure Logic)

**`app/domain/services/incident_decision_calculator.rb`**:

```ruby
module Domain
  module Services
    class IncidentDecisionCalculator
      # Pure business logic - no persistence
      def self.can_apply_decision?(incident, user)
        return false unless incident.official?
        return false unless incident.pending?
        return false unless user.can_decide?
        true
      end

      def self.calculate_penalty_points(decision_type, severity)
        case [decision_type, severity]
        when ["time_penalty", "minor"] then 30
        when ["time_penalty", "major"] then 60
        when ["disqualification", _] then Float::INFINITY
        else 0
        end
      end
    end
  end
end
```

---

### Phase 2: Infrastructure Layer - Persistence

**Goal**: Create ActiveRecord adapters and repositories

#### Task 2.1: Rename ActiveRecord Models to Records

**`app/infrastructure/persistence/records/report_record.rb`**:

```ruby
module Infrastructure
  module Persistence
    module Records
      class ReportRecord < ApplicationRecord
        self.table_name = "reports"

        belongs_to :race_record, foreign_key: "race_id"
        belongs_to :incident_record, foreign_key: "incident_id", optional: true
        belongs_to :user_record, foreign_key: "user_id"
        belongs_to :race_location_record, foreign_key: "race_location_id", optional: true

        has_one_attached :video

        # NO validations (handled in domain)
        # NO callbacks (handled in application layer)
        # NO business logic

        scope :ordered, -> { order(created_at: :desc) }
        scope :by_bib, ->(bib) { where(bib_number: bib) }
      end
    end
  end
end
```

**`app/infrastructure/persistence/records/incident_record.rb`**:

```ruby
module Infrastructure
  module Persistence
    module Records
      class IncidentRecord < ApplicationRecord
        self.table_name = "incidents"

        belongs_to :race_record, foreign_key: "race_id"
        belongs_to :race_location_record, foreign_key: "race_location_id", optional: true
        belongs_to :officialized_by_user_record, 
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "officialized_by_user_id",
                   optional: true
        belongs_to :decided_by_user_record,
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "decided_by_user_id",
                   optional: true

        has_many :report_records, foreign_key: "incident_id"

        enum :status, { unofficial: 0, official: 1 }
        enum :decision, { 
          pending: 0, 
          penalty_applied: 1, 
          rejected: 2, 
          no_action: 3 
        }

        # NO validations
        # NO callbacks
        # NO business logic

        scope :ordered, -> { order(created_at: :desc) }
        scope :unofficial, -> { where(status: :unofficial) }
        scope :official, -> { where(status: :official) }
        scope :pending_decision, -> { where(decision: :pending) }
      end
    end
  end
end
```

**`app/infrastructure/persistence/records/user_record.rb`**:

```ruby
module Infrastructure
  module Persistence
    module Records
      class UserRecord < ApplicationRecord
        self.table_name = "users"

        has_secure_password

        has_many :session_records, foreign_key: "user_id", dependent: :destroy
        has_many :report_records, foreign_key: "user_id"

        enum :referee_level, {
          national_referee: 0,
          international_referee: 1,
          referee_manager: 2,
          var_operator: 3
        }, prefix: :level

        # NO business logic
        # NO validations (domain handles this)
      end
    end
  end
end
```

**`app/infrastructure/persistence/records/race_record.rb`**:

```ruby
module Infrastructure
  module Persistence
    module Records
      class RaceRecord < ApplicationRecord
        self.table_name = "races"

        has_many :incident_records, foreign_key: "race_id"
        has_many :report_records, foreign_key: "race_id"

        enum :status, { upcoming: 0, active: 1, completed: 2 }

        scope :active, -> { where(status: :active) }
      end
    end
  end
end
```

#### Task 2.2: Create Repositories (Mappers)

**`app/infrastructure/persistence/repositories/report_repository.rb`**:

```ruby
require "dry/monads"

module Infrastructure
  module Persistence
    module Repositories
      class ReportRepository
        include Dry::Monads[:result]

        def find(id)
          record = Records::ReportRecord.find_by(id: id)
          return Failure(:not_found) unless record

          Success(to_entity(record))
        end

        def create(attributes)
          record = Records::ReportRecord.new(attributes)
          
          if record.save
            Success(to_entity(record))
          else
            Failure(record.errors.to_hash)
          end
        end

        def by_race(race_id)
          records = Records::ReportRecord
            .where(race_id: race_id)
            .ordered
            .to_a

          Success(records.map { |r| to_entity(r) })
        end

        def by_bib_number(race_id, bib_number)
          records = Records::ReportRecord
            .where(race_id: race_id, bib_number: bib_number)
            .ordered
            .to_a

          Success(records.map { |r| to_entity(r) })
        end

        def recent(limit: 50)
          records = Records::ReportRecord
            .ordered
            .limit(limit)
            .to_a

          Success(records.map { |r| to_entity(r) })
        end

        def attach_video(report_id, video_file)
          record = Records::ReportRecord.find(report_id)
          record.video.attach(video_file)
          
          Success(to_entity(record))
        rescue ActiveRecord::RecordNotFound
          Failure(:not_found)
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
            race_location_id: record.race_location_id,
            athlete_name: record.athlete_name,
            description: record.description,
            video_url: record.video.attached? ? Rails.application.routes.url_helpers.rails_blob_url(record.video) : nil,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
```

**`app/infrastructure/persistence/repositories/incident_repository.rb`**:

```ruby
require "dry/monads"

module Infrastructure
  module Persistence
    module Repositories
      class IncidentRepository
        include Dry::Monads[:result]

        def find(id)
          record = Records::IncidentRecord.find_by(id: id)
          return Failure(:not_found) unless record

          Success(to_entity(record))
        end

        def create(attributes)
          record = Records::IncidentRecord.new(attributes)
          
          if record.save
            Success(to_entity(record))
          else
            Failure(record.errors.to_hash)
          end
        end

        def update(id, attributes)
          record = Records::IncidentRecord.find(id)
          
          if record.update(attributes)
            Success(to_entity(record))
          else
            Failure(record.errors.to_hash)
          end
        rescue ActiveRecord::RecordNotFound
          Failure(:not_found)
        end

        def by_race(race_id)
          records = Records::IncidentRecord
            .where(race_id: race_id)
            .ordered
            .to_a

          Success(records.map { |r| to_entity(r) })
        end

        def pending_decisions(race_id)
          records = Records::IncidentRecord
            .official
            .pending_decision
            .where(race_id: race_id)
            .ordered
            .to_a

          Success(records.map { |r| to_entity(r) })
        end

        def merge_incidents(target_id, source_ids)
          Records::IncidentRecord.transaction do
            target = Records::IncidentRecord.find(target_id)
            sources = Records::IncidentRecord.where(id: source_ids)

            # Move reports to target
            Records::ReportRecord.where(incident_id: source_ids).update_all(incident_id: target_id)

            # Delete source incidents
            sources.destroy_all

            Success(to_entity(target.reload))
          end
        rescue ActiveRecord::RecordNotFound
          Failure(:not_found)
        rescue => e
          Failure(e.message)
        end

        private

        def to_entity(record)
          Domain::Entities::Incident.new(
            id: record.id,
            race_id: record.race_id,
            race_location_id: record.race_location_id,
            status: record.status,
            decision: record.decision,
            officialized_by_user_id: record.officialized_by_user_id,
            decided_by_user_id: record.decided_by_user_id,
            officialized_at: record.officialized_at,
            decided_at: record.decided_at,
            decision_notes: record.decision_notes,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
```

#### Task 2.3: Register Repositories in Container

Update **`config/initializers/dry_container.rb`**:

```ruby
require "dry/container"
require "dry/auto_inject"

class ApplicationContainer
  extend Dry::Container::Mixin

  # Repositories
  namespace :repositories do
    register :report do
      Infrastructure::Persistence::Repositories::ReportRepository.new
    end

    register :incident do
      Infrastructure::Persistence::Repositories::IncidentRepository.new
    end

    register :race do
      Infrastructure::Persistence::Repositories::RaceRepository.new
    end

    register :user do
      Infrastructure::Persistence::Repositories::UserRepository.new
    end
  end
end

Import = Dry::AutoInject(ApplicationContainer)
```

---

### Phase 3: Application Layer - Commands & Queries

**Goal**: Create use case orchestration

#### Task 3.1: Create Report Commands

**`app/application/commands/reports/create.rb`**:

```ruby
require "dry/monads"
require "dry/monads/do"

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
          
          # Ensure race exists and is active
          race = yield race_repository.find(validated[:race_id])
          yield ensure_race_active(race)
          
          # Find or create incident
          incident = yield find_or_create_incident(validated)
          
          # Set required fields
          report_attrs = validated.merge(
            user_id: current_user_id,
            incident_id: incident.id
          )
          
          # Create report
          report = yield report_repository.create(report_attrs)
          
          # Broadcast to desktop (async)
          BroadcastReportJob.perform_later(report.id)
          
          Success(report)
        end

        private

        def validate(params)
          contract = Domain::Contracts::ReportContract.new
          result = contract.call(params)
          
          if result.success?
            Success(result.to_h)
          else
            Failure([:validation_failed, result.errors.to_h])
          end
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
              race_location_id: validated[:race_location_id],
              status: "unofficial",
              decision: "pending"
            )
          end
        end
      end
    end
  end
end
```

**`app/application/commands/reports/attach_video.rb`**:

```ruby
require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Reports
      class AttachVideo
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.report"]

        def call(report_id, video_file)
          # Find report
          report = yield report_repository.find(report_id)
          
          # Attach video
          updated_report = yield report_repository.attach_video(report_id, video_file)
          
          # Process video async
          ProcessVideoJob.perform_later(report_id)
          
          Success(updated_report)
        end
      end
    end
  end
end
```

#### Task 3.2: Create Incident Commands

**`app/application/commands/incidents/merge.rb`**:

```ruby
require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Incidents
      class Merge
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.incident"]

        def call(target_id, source_ids, current_user)
          # Authorization check
          yield authorize(current_user)
          
          # Find target
          target = yield incident_repository.find(target_id)
          
          # Validate same race
          yield validate_same_race(target, source_ids)
          
          # Perform merge
          merged = yield incident_repository.merge_incidents(target_id, source_ids)
          
          # Broadcast update
          BroadcastIncidentJob.perform_later(merged.id)
          
          Success(merged)
        end

        private

        def authorize(user)
          user.admin? ? Success(user) : Failure([:unauthorized, "Admin access required"])
        end

        def validate_same_race(target, source_ids)
          incident_repository.find_many(source_ids).bind do |sources|
            all_same = sources.all? { |s| s.race_id == target.race_id }
            all_same ? Success(true) : Failure([:invalid_merge, "All incidents must be from the same race"])
          end
        end
      end
    end
  end
end
```

**`app/application/commands/incidents/officialize.rb`**:

```ruby
require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Incidents
      class Officialize
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.incident"]

        def call(incident_id, current_user)
          # Find incident
          incident = yield incident_repository.find(incident_id)
          
          # Authorize
          yield authorize(current_user, incident)
          
          # Validate can officialize
          yield validate_can_officialize(incident)
          
          # Update
          updated = yield incident_repository.update(incident_id, {
            status: "official",
            officialized_by_user_id: current_user.id,
            officialized_at: Time.current
          })
          
          # Notify
          NotifyOfficializationJob.perform_later(updated.id)
          
          Success(updated)
        end

        private

        def authorize(user, incident)
          user.can_officialize? ? Success(user) : Failure([:unauthorized, "Referee access required"])
        end

        def validate_can_officialize(incident)
          incident.can_officialize? ? Success(incident) : Failure([:invalid_state, "Incident already official"])
        end
      end
    end
  end
end
```

**`app/application/commands/incidents/apply_penalty.rb`**:

```ruby
require "dry/monads"
require "dry/monads/do"

module Application
  module Commands
    module Incidents
      class ApplyPenalty
        include Dry::Monads[:result]
        include Dry::Monads::Do.for(:call)
        include Import["repositories.incident"]

        def call(incident_id, decision_notes, current_user)
          # Find incident
          incident = yield incident_repository.find(incident_id)
          
          # Authorize
          yield authorize(current_user, incident)
          
          # Validate can decide
          yield validate_can_decide(incident)
          
          # Update
          updated = yield incident_repository.update(incident_id, {
            decision: "penalty_applied",
            decided_by_user_id: current_user.id,
            decided_at: Time.current,
            decision_notes: decision_notes
          })
          
          # Notify
          NotifyDecisionJob.perform_later(updated.id)
          
          Success(updated)
        end

        private

        def authorize(user, incident)
          user.can_decide? ? Success(user) : Failure([:unauthorized, "Referee manager access required"])
        end

        def validate_can_decide(incident)
          incident.can_decide? ? Success(incident) : Failure([:invalid_state, "Incident cannot be decided"])
        end
      end
    end
  end
end
```

#### Task 3.3: Create Queries

**`app/application/queries/reports/by_race.rb`**:

```ruby
require "dry/monads"

module Application
  module Queries
    module Reports
      class ByRace
        include Dry::Monads[:result]
        include Import["repositories.report"]

        def call(race_id)
          report_repository.by_race(race_id)
        end
      end
    end
  end
end
```

**`app/application/queries/incidents/pending_decision.rb`**:

```ruby
require "dry/monads"

module Application
  module Queries
    module Incidents
      class PendingDecision
        include Dry::Monads[:result]
        include Import["repositories.incident"]

        def call(race_id)
          incident_repository.pending_decisions(race_id)
        end
      end
    end
  end
end
```

#### Task 3.4: Register Commands in Container

Update **`config/initializers/dry_container.rb`**:

```ruby
# ... existing code ...

# Commands
namespace :commands do
  namespace :reports do
    register :create do
      Application::Commands::Reports::Create.new
    end

    register :attach_video do
      Application::Commands::Reports::AttachVideo.new
    end
  end

  namespace :incidents do
    register :merge do
      Application::Commands::Incidents::Merge.new
    end

    register :officialize do
      Application::Commands::Incidents::Officialize.new
    end

    register :apply_penalty do
      Application::Commands::Incidents::ApplyPenalty.new
    end

    register :reject do
      Application::Commands::Incidents::Reject.new
    end
  end
end

# Queries
namespace :queries do
  namespace :reports do
    register :by_race do
      Application::Queries::Reports::ByRace.new
    end
  end

  namespace :incidents do
    register :pending_decision do
      Application::Queries::Incidents::PendingDecision.new
    end
  end
end
```

---

### Phase 4: Web Layer - Thin Controllers

**Goal**: Convert controllers to thin adapters

#### Task 4.1: Create Base Controller with Dependency Injection

**`app/web/controllers/application_controller.rb`**:

```ruby
module Web
  module Controllers
    class ApplicationController < ActionController::Base
      include Authentication

      # Inject dependencies
      def create_report_command
        ApplicationContainer.resolve("commands.reports.create")
      end

      def attach_video_command
        ApplicationContainer.resolve("commands.reports.attach_video")
      end

      def merge_incidents_command
        ApplicationContainer.resolve("commands.incidents.merge")
      end

      def officialize_incident_command
        ApplicationContainer.resolve("commands.incidents.officialize")
      end

      def apply_penalty_command
        ApplicationContainer.resolve("commands.incidents.apply_penalty")
      end

      def reports_by_race_query
        ApplicationContainer.resolve("queries.reports.by_race")
      end

      def pending_decisions_query
        ApplicationContainer.resolve("queries.incidents.pending_decision")
      end

      private

      def current_user_entity
        return nil unless Current.user

        Domain::Entities::User.new(
          id: Current.user.id,
          email: Current.user.email,
          name: Current.user.name,
          admin: Current.user.admin,
          referee_level: Current.user.referee_level
        )
      end

      def handle_result(result, success_path: nil, &block)
        result.either(
          ->(value) {
            if block_given?
              block.call(value)
            else
              redirect_to success_path, notice: "Success"
            end
          },
          ->(error) {
            case error
            in [:validation_failed, errors]
              render :new, status: :unprocessable_entity, locals: { errors: errors }
            in [:not_found, _]
              redirect_to root_path, alert: "Not found"
            in [:unauthorized, message]
              redirect_to root_path, alert: message
            else
              redirect_to root_path, alert: "An error occurred"
            end
          }
        )
      end
    end
  end
end
```

#### Task 4.2: Create API Reports Controller (FOP Devices)

**`app/web/controllers/api/reports_controller.rb`**:

```ruby
module Web
  module Controllers
    module Api
      class ReportsController < ApplicationController
        # Speed-optimized for FOP devices
        skip_before_action :verify_authenticity_token
        before_action :require_authentication

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

        def attach_video
          result = attach_video_command.call(params[:id], params[:video])

          handle_result(result) do |report|
            render json: { id: report.id, video_url: report.video_url }
          end
        end

        private

        def report_params
          params.require(:report).permit(
            :client_uuid,
            :race_id,
            :bib_number,
            :description,
            :race_location_id,
            :athlete_name,
            :incident_id
          ).to_h.symbolize_keys
        end
      end
    end
  end
end
```

#### Task 4.3: Create Admin Incidents Controller (Desktop)

**`app/web/controllers/admin/incidents_controller.rb`**:

```ruby
module Web
  module Controllers
    module Admin
      class IncidentsController < ApplicationController
        before_action :require_admin

        def index
          result = pending_decisions_query.call(params[:race_id])

          handle_result(result) do |incidents|
            render :index, locals: { incidents: incidents }
          end
        end

        def show
          # Implementation
        end

        def merge
          result = merge_incidents_command.call(
            params[:target_id],
            params[:source_ids],
            current_user_entity
          )

          handle_result(result, success_path: admin_incidents_path) do |incident|
            redirect_to admin_incident_path(incident.id), notice: "Incidents merged"
          end
        end

        def officialize
          result = officialize_incident_command.call(params[:id], current_user_entity)

          handle_result(result, success_path: admin_incidents_path) do |incident|
            respond_to do |format|
              format.html { redirect_to admin_incident_path(incident.id), notice: "Incident officialized" }
              format.turbo_stream { render turbo_stream: turbo_stream.replace("incident_#{incident.id}", partial: "incident", locals: { incident: incident }) }
            end
          end
        end

        def apply_penalty
          result = apply_penalty_command.call(
            params[:id],
            params[:decision_notes],
            current_user_entity
          )

          handle_result(result, success_path: admin_incidents_path) do |incident|
            respond_to do |format|
              format.html { redirect_to admin_incident_path(incident.id), notice: "Penalty applied" }
              format.turbo_stream { render turbo_stream: turbo_stream.replace("incident_#{incident.id}", partial: "incident", locals: { incident: incident }) }
            end
          end
        end

        private

        def require_admin
          redirect_to root_path, alert: "Not authorized" unless current_user_entity&.admin?
        end
      end
    end
  end
end
```

---

### Phase 5: Testing Strategy

**Goal**: Test each layer in isolation

#### Task 5.1: Domain Layer Tests (Unit Tests)

**`spec/domain/entities/incident_spec.rb`**:

```ruby
require "rails_helper"

RSpec.describe Domain::Entities::Incident do
  describe "#can_officialize?" do
    it "returns true when status is unofficial" do
      incident = described_class.new(
        race_id: 1,
        status: "unofficial",
        decision: "pending"
      )

      expect(incident.can_officialize?).to be true
    end

    it "returns false when status is official" do
      incident = described_class.new(
        race_id: 1,
        status: "official",
        decision: "pending"
      )

      expect(incident.can_officialize?).to be false
    end
  end

  describe "#can_decide?" do
    it "returns true when official and pending" do
      incident = described_class.new(
        race_id: 1,
        status: "official",
        decision: "pending"
      )

      expect(incident.can_decide?).to be true
    end

    it "returns false when unofficial" do
      incident = described_class.new(
        race_id: 1,
        status: "unofficial",
        decision: "pending"
      )

      expect(incident.can_decide?).to be false
    end
  end
end
```

#### Task 5.2: Repository Tests (Integration with Database)

**`spec/infrastructure/persistence/repositories/report_repository_spec.rb`**:

```ruby
require "rails_helper"

RSpec.describe Infrastructure::Persistence::Repositories::ReportRepository do
  let(:repository) { described_class.new }

  describe "#create" do
    it "creates a report and returns entity" do
      attributes = {
        client_uuid: SecureRandom.uuid,
        race_id: 1,
        user_id: 1,
        bib_number: 42,
        description: "Test incident"
      }

      result = repository.create(attributes)

      expect(result).to be_success
      
      result.value! => Domain::Entities::Report => report
      expect(report.bib_number).to eq(42)
      expect(report.description).to eq("Test incident")
    end
  end

  describe "#by_race" do
    it "returns reports for a race" do
      # Setup
      race_id = create(:race_record).id
      create_list(:report_record, 3, race_id: race_id)

      result = repository.by_race(race_id)

      expect(result).to be_success
      expect(result.value!.size).to eq(3)
      expect(result.value!.first).to be_a(Domain::Entities::Report)
    end
  end
end
```

#### Task 5.3: Application Layer Tests (Use Case Tests)

**`spec/application/commands/reports/create_spec.rb`**:

```ruby
require "rails_helper"

RSpec.describe Application::Commands::Reports::Create do
  let(:command) { described_class.new }

  describe "#call" do
    let(:user_id) { create(:user_record).id }
    let(:race) { create(:race_record, status: :active) }
    
    let(:valid_params) do
      {
        client_uuid: SecureRandom.uuid,
        race_id: race.id,
        bib_number: 42,
        description: "Potential violation"
      }
    end

    context "with valid params" do
      it "creates a report" do
        result = command.call(valid_params, user_id)

        expect(result).to be_success
        
        result.value! => Domain::Entities::Report => report
        expect(report.bib_number).to eq(42)
        expect(report.user_id).to eq(user_id)
        expect(report.incident_id).to be_present
      end

      it "creates an incident if not provided" do
        expect {
          command.call(valid_params, user_id)
        }.to change { Infrastructure::Persistence::Records::IncidentRecord.count }.by(1)
      end
    end

    context "with invalid params" do
      it "returns validation failure" do
        invalid_params = valid_params.merge(bib_number: nil)
        result = command.call(invalid_params, user_id)

        expect(result).to be_failure
        expect(result.failure.first).to eq(:validation_failed)
      end
    end

    context "when race is not active" do
      it "returns failure" do
        race.update!(status: :completed)
        result = command.call(valid_params, user_id)

        expect(result).to be_failure
        expect(result.failure).to eq([:race_not_active, race.id])
      end
    end
  end
end
```

#### Task 5.4: Web Layer Tests (Request Specs)

**`spec/web/controllers/api/reports_controller_spec.rb`**:

```ruby
require "rails_helper"

RSpec.describe Web::Controllers::Api::ReportsController, type: :request do
  let(:user) { create(:user_record) }
  let(:race) { create(:race_record, status: :active) }

  before do
    sign_in(user)
  end

  describe "POST /api/reports" do
    let(:valid_params) do
      {
        report: {
          client_uuid: SecureRandom.uuid,
          race_id: race.id,
          bib_number: 42,
          description: "Test incident"
        }
      }
    end

    it "creates a report" do
      post api_reports_path, params: valid_params

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["bib_number"]).to eq(42)
    end

    it "returns validation errors for invalid params" do
      invalid_params = valid_params.deep_merge(report: { bib_number: nil })

      post api_reports_path, params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

---

### Phase 6: Packwerk Validation

**Goal**: Enforce architectural boundaries

#### Task 6.1: Run Packwerk Check

```bash
docker compose exec app bundle exec packwerk check
```

#### Task 6.2: Fix Violations

If violations are found, they must be fixed before proceeding. Common violations:

1. **Domain referencing Rails**:
   ```
   app/domain/entities/report.rb:1:0
   Privacy violation: '::Rails' is private to 'app/web'
   ```
   
   **Fix**: Remove Rails reference, use dependency injection

2. **Web accessing Infrastructure directly**:
   ```
   app/web/controllers/reports_controller.rb:10:0
   Dependency violation: app/web cannot depend on app/infrastructure
   ```
   
   **Fix**: Access through application layer

#### Task 6.3: Generate Documentation

```bash
docker compose exec app bundle exec packwerk visualize
```

This generates a dependency graph showing layer boundaries.

---

## Migration Path to Hanami 2 (Future)

**IMPORTANT**: This Rails app does NOT include Hanami gem. Migration to Hanami happens later as a separate deployment.

### Current State (Rails + dry-rb)

```
Rails Application (this repo)
├── Uses dry-rb for domain/application layers
├── Uses Rails/ActiveRecord for web/infrastructure
└── Hanami-compatible architecture (NOT Hanami itself)
```

### Future State (Hanami)

```
Hanami Application (new repo)
├── Copy domain/ and application/ as-is
├── Replace Rails with Hanami web layer
├── Replace ActiveRecord with ROM
└── Deploy alongside Rails, then switch DNS
```

### Expected Changes by Layer

#### Domain Layer: **0 changes required**
All domain code is framework-agnostic and can be copied directly to Hanami.

#### Application Layer: **0 changes required**
Use cases use dry-rb primitives that work identically in Hanami.

#### Infrastructure Layer: **Adapter swap**
- Replace ActiveRecord with ROM
- Change: `Records::ReportRecord` → ROM relations
- Repositories updated to use ROM instead of ActiveRecord
- Estimated effort: 2-3 days

#### Web Layer: **Mechanical rewrite**
- Move controllers to `slices/web/actions/`
- Update routing DSL (Rails routes → Hanami routes)
- Views require minimal changes (ERB works in both)
- Estimated effort: 3-5 days

### Migration Steps (When Ready)

1. **Create NEW Hanami 2 project** (separate repo)
2. **Copy domain/ directory** (unchanged)
3. **Copy application/ directory** (unchanged)
4. **Rewrite infrastructure/** (ROM repositories)
5. **Rewrite web/** (Hanami actions)
6. **Update config/** (Hanami boot files)
7. **Run tests** (same specs, different setup)
8. **Deploy Hanami app** to staging
9. **Switch DNS** when ready

**Total estimated migration time: 1-2 weeks**

**Why not migrate now?**
- Rails works well for our current needs
- Hanami 2 is still maturing
- This architecture protects our investment
- We can migrate when business case justifies it

---

## Summary

This architecture provides:

✅ **Clean separation of concerns**
✅ **Framework independence** (domain + application)
✅ **Testability** (each layer tested in isolation)
✅ **Packwerk enforcement** (architectural integrity)
✅ **Hanami-compatible** (near-zero migration cost)
✅ **Turbo Native support** (mobile apps unaffected by migration)

### Key Takeaways

1. **Rails is an adapter** - It wraps the real application
2. **Business logic in domain** - Framework-agnostic, portable
3. **Use cases in application** - Orchestration with dry-rb
4. **ActiveRecord in infrastructure** - Persistence is a detail
5. **Controllers are thin** - Just HTTP handling
6. **Packwerk enforces boundaries** - Prevent architectural drift

### Next Steps

1. Review this plan with the team
2. Start with Phase 0 (Foundation Setup)
3. Implement one feature end-to-end as proof of concept
4. Migrate existing code incrementally
5. Run Packwerk continuously in CI/CD

---

## Appendix: Dry-rb Quick Reference

### dry-struct

```ruby
class User < Dry::Struct
  attribute :name, Types::String
  attribute :age, Types::Integer.optional
end
```

### dry-validation

```ruby
class UserContract < Dry::Validation::Contract
  params do
    required(:name).filled(:string)
    required(:age).filled(:integer, gt?: 18)
  end
end
```

### dry-monads

```ruby
def call
  Success(value)  # Happy path
  Failure(error)  # Error path
end

# Pattern matching (Ruby 3.0+)
result.either(
  ->(value) { puts "Success: #{value}" },
  ->(error) { puts "Error: #{error}" }
)
```

### dry-auto_inject

```ruby
class CreateUser
  include Import["repositories.user"]
  
  def call(params)
    user_repository.create(params)
  end
end
```

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Ready for Implementation