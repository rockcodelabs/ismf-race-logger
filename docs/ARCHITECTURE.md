# ISMF Race Logger - Architecture

> Hanami-Hybrid Architecture: Rails 8.1 + dry-rb gems

This document is the single source of truth for the ISMF Race Logger architecture.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Layer Responsibilities](#layer-responsibilities)
4. [Directory Structure](#directory-structure)
5. [Models](#models)
6. [Structs](#structs)
7. [Repos](#repos)
8. [Operations](#operations)
9. [Contracts](#contracts)
10. [Controllers](#controllers)
11. [Parts](#parts)
12. [Broadcasters](#broadcasters)
13. [Dependency Injection](#dependency-injection)
14. [Types](#types)
15. [Packwerk Boundaries](#packwerk-boundaries)
16. [Real-Time Architecture](#real-time-architecture)
17. [Turbo Native Support](#turbo-native-support)
18. [Offline Sync Architecture](#offline-sync-architecture)
19. [Performance Patterns](#performance-patterns)
20. [Testing Strategy](#testing-strategy)
21. [Quick Reference](#quick-reference)

---

## Overview

The ISMF Race Logger uses a **Hanami-Hybrid Architecture** - a Rails 8.1 application structured to follow Hanami 2.x conventions using dry-rb gems. This provides:

- **Performance**: Ruby `Data` class for collections (7x faster than dry-struct)
- **Type Safety**: dry-struct for single records with full validation
- **Testability**: dry-auto_inject for dependency injection
- **Boundary Enforcement**: Packwerk ensures layer separation
- **Real-Time Ready**: Turbo Streams with dedicated Broadcasters
- **Turbo Native**: Shared views with platform-specific variants

### Key Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Framework** | Rails 8.1 + dry-rb | Best of both worlds |
| **Structs** | `Structs::User` | Hanami convention |
| **Collections** | Ruby `Data` class | Performance (7x faster) |
| **Operations** | dry-monads results | Explicit success/failure |
| **Validation** | dry-validation | Separated from persistence |
| **DI** | dry-auto_inject | Testable, injectable |
| **Boundaries** | Packwerk | Strict enforcement |
| **Real-time** | Turbo Streams + Broadcasters | Separation of concerns |
| **Presentation** | Parts (decorators) | Clean templates |

---

## Architecture Diagram

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

---

## Layer Responsibilities

| Layer | Location | Responsibility |
|-------|----------|----------------|
| **Models** | `app/models/` | Thin ActiveRecord (associations only, no logic) |
| **Structs** | `app/db/structs/` | Immutable domain objects (dry-struct + Ruby Data) |
| **Repos** | `app/db/repos/` | Data access (returns structs, not AR models) |
| **Operations** | `app/operations/` | Business logic (dry-monads, dry-validation) |
| **Contracts** | `app/operations/contracts/` | Input validation (dry-validation) |
| **Controllers** | `app/web/controllers/` | Thin HTTP adapters (call operations) |
| **Parts** | `app/web/parts/` | View presentation logic (wrap structs) |
| **Templates** | `app/views/` | ERB views (use parts, no logic) |
| **Broadcasters** | `app/broadcasters/` | Real-time Turbo Stream delivery |

### Dependencies Flow (Enforced by Packwerk)

```
app/web → app/operations → app/db → app/models
               ↓
          (lib/types)
```

**Never upward!** Packwerk prevents reverse dependencies.

---

## Directory Structure

```
app/
├── db/                              # Layer 1: Persistence
│   ├── repo.rb                      # DB::Repo base class
│   ├── struct.rb                    # DB::Struct base class
│   ├── repos/                       # Repository implementations
│   │   ├── user_repo.rb
│   │   ├── role_repo.rb
│   │   ├── session_repo.rb
│   │   └── incident_repo.rb
│   └── structs/                     # Immutable data objects
│       ├── user.rb                  # Full struct (dry-struct)
│       ├── user_summary.rb          # Summary struct (Ruby Data)
│       └── incident.rb
│
├── operations/                      # Layer 2: Use cases
│   ├── contracts/                   # Input validation
│   │   ├── authenticate_user.rb
│   │   └── create_incident.rb
│   ├── users/
│   │   ├── authenticate.rb
│   │   ├── create.rb
│   │   └── find.rb
│   └── incidents/
│       ├── create.rb
│       └── update.rb
│
├── models/                          # Thin ActiveRecord
│   ├── application_record.rb
│   ├── user.rb
│   ├── role.rb
│   ├── session.rb
│   └── incident.rb
│
├── web/                             # Layer 3: HTTP interface
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── concerns/
│   │   │   └── authentication.rb
│   │   ├── sessions_controller.rb
│   │   └── admin/
│   │       ├── base_controller.rb
│   │       └── users_controller.rb
│   ├── parts/
│   │   ├── base.rb
│   │   ├── factory.rb
│   │   ├── user.rb
│   │   └── incident.rb
│   └── package.yml
│
├── views/                           # ERB templates (Rails convention)
│   ├── layouts/
│   │   ├── application.html.erb
│   │   ├── application.turbo_native.html.erb
│   │   ├── admin.html.erb
│   │   └── admin.turbo_native.html.erb
│   ├── sessions/
│   ├── admin/
│   └── shared/
│
├── broadcasters/                    # Real-time broadcasts
│   ├── base_broadcaster.rb
│   └── incident_broadcaster.rb
│
└── javascript/
    └── controllers/                 # Stimulus controllers

lib/
└── ismf_race_logger/
    └── types.rb                     # Shared dry-types

config/
└── initializers/
    └── container.rb                 # DI container
```

---

## Models

Pure data mappers with **no business logic**:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  # Associations only
  belongs_to :role, optional: true
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  # Simple validations
  validates :email_address, presence: true, uniqueness: true
  validates :name, presence: true
end
```

**Rules:**
- ✅ Associations
- ✅ Simple validations (presence, uniqueness)
- ✅ has_secure_password
- ❌ NO scopes (use Repo methods)
- ❌ NO business logic
- ❌ NO callbacks with logic

---

## Structs

Immutable domain objects. Two types for performance:

### Full Struct (dry-struct) - For Single Records

```ruby
# app/db/structs/user.rb
# frozen_string_literal: true

module Structs
  # Immutable representation of a User record
  class User < DB::Struct
    attribute :id, Types::Integer
    attribute :email_address, Types::String
    attribute :name, Types::String
    attribute :admin, Types::Bool.optional.default(false)
    attribute :role_name, Types::String.optional
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Domain methods (no presentation logic)
    def display_name
      name.presence || email_address.split("@").first
    end

    def admin? = admin == true
    def referee? = role_name&.include?("referee")
    def var_operator? = role_name == "var_operator"
  end
end
```

### Summary Struct (Ruby Data) - For Collections

```ruby
# app/db/structs/user_summary.rb
# frozen_string_literal: true

module Structs
  # Lightweight struct for User collections (7x faster than dry-struct)
  UserSummary = Data.define(:id, :email_address, :name, :admin, :role_name) do
    def display_name
      name.presence || email_address.split("@").first
    end

    def admin? = admin == true
    def referee? = role_name&.include?("referee")
  end
end
```

### When to Use Which?

| Scenario | Struct Type | Class |
|----------|-------------|-------|
| `find(id)`, `find!`, `find_by` | Full | `Structs::User` |
| `all`, `where`, `search` | Summary | `Structs::UserSummary` |
| Single record operations | Full | Type-safe, validated |
| List/index pages | Summary | Fast, minimal |

---

## Repos

Data access layer that returns structs, not AR models:

```ruby
# app/db/repos/user_repo.rb
# frozen_string_literal: true

# Repository for User persistence operations
class UserRepo < DB::Repo
  # Declare which methods return single vs. collections
  returns_one :find_by_email, :authenticate
  returns_many :admins, :referees, :search

  def find_by_email(email)
    find_by(email_address: email)
  end

  def authenticate(email, password)
    record = User.find_by(email_address: email)
    return nil unless record&.authenticate(password)
    build_struct(record)
  end

  def admins
    where(admin: true)
  end

  def referees
    User.joins(:role)
        .where(roles: { name: %w[national_referee international_referee] })
        .map { |r| build_summary(r) }
  end

  protected

  def base_scope
    User.includes(:role)
  end

  def build_struct(record)
    Structs::User.new(
      id: record.id,
      email_address: record.email_address,
      name: record.name,
      admin: record.admin?,
      role_name: record.role&.name,
      created_at: record.created_at,
      updated_at: record.updated_at
    )
  end

  def build_summary(record)
    Structs::UserSummary.new(
      id: record.id,
      email_address: record.email_address,
      name: record.name,
      admin: record.admin?,
      role_name: record.role&.name
    )
  end
end
```

### Base Repo (`app/db/repo.rb`)

```ruby
# frozen_string_literal: true

module DB
  # Base repository class providing common CRUD operations
  class Repo
    class << self
      def returns_one(*methods)
        @one_methods ||= []
        @one_methods.concat(methods)
      end

      def returns_many(*methods)
        @many_methods ||= []
        @many_methods.concat(methods)
      end
    end

    # Single record methods → Return full struct (or nil)
    def find(id)
      record = base_scope.find_by(id: id)
      to_struct(record)
    end

    def find!(id)
      record = base_scope.find(id)
      to_struct(record)
    end

    def find_by(**conditions)
      record = base_scope.find_by(**conditions)
      to_struct(record)
    end

    # Collection methods → Return summary structs
    def all
      base_scope.map { |r| to_summary(r) }
    end

    def where(**conditions)
      base_scope.where(**conditions).map { |r| to_summary(r) }
    end

    # CRUD
    def create(attrs)
      record = record_class.create!(attrs)
      to_struct(record)
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def update(id, attrs)
      record = record_class.find(id)
      record.update!(attrs)
      to_struct(record)
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
      nil
    end

    def delete(id)
      record_class.find(id).destroy
      true
    rescue ActiveRecord::RecordNotFound
      nil
    end

    protected

    def record_class
      # Infer from class name: UserRepo → User
      self.class.name.sub("Repo", "").constantize
    end

    def base_scope
      record_class.all
    end

    def to_struct(record)
      return nil unless record
      build_struct(record)
    end

    def to_summary(record)
      return nil unless record
      build_summary(record)
    end

    def build_struct(record)
      raise NotImplementedError, "#{self.class} must implement #build_struct"
    end

    def build_summary(record)
      raise NotImplementedError, "#{self.class} must implement #build_summary"
    end
  end
end
```

---

## Operations

Use cases with dry-monads for explicit success/failure:

```ruby
# app/operations/users/authenticate.rb
# frozen_string_literal: true

module Operations
  module Users
    # Authenticates a user with email and password
    class Authenticate
      include Dry::Monads[:result]
      include Dry::Monads::Do.for(:call)
      include Import["repos.user"]

      def call(email:, password:)
        validated = yield validate(email, password)

        user = repos_user.authenticate(validated[:email], validated[:password])
        return Failure(:invalid_credentials) unless user

        Success(user)
      end

      private

      def validate(email, password)
        contract = Operations::Contracts::AuthenticateUser.new
        result = contract.call(email: email, password: password)

        result.success? ? Success(result.to_h) : Failure([:validation_failed, result.errors.to_h])
      end
    end
  end
end
```

### Operation Patterns

```ruby
# Command pattern (with side effects)
module Operations
  module Incidents
    class Create
      include Dry::Monads[:result]
      include Import["repos.incident", "broadcasters.incident"]

      def call(params, created_by:)
        contract = Operations::Contracts::CreateIncident.new
        validation = contract.call(params)

        return Failure(validation.errors.to_h) unless validation.success?

        incident = repos_incident.create(validation.to_h.merge(created_by_id: created_by.id))
        return Failure(:creation_failed) unless incident

        # Broadcast real-time update
        broadcasters_incident.created(incident)

        Success(incident)
      end
    end
  end
end
```

---

## Contracts

Input validation with dry-validation:

```ruby
# app/operations/contracts/authenticate_user.rb
# frozen_string_literal: true

module Operations
  module Contracts
    # Validates authentication input
    class AuthenticateUser < Dry::Validation::Contract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string, min_size?: 6)
      end

      rule(:email) do
        unless /\A[^@\s]+@[^@\s]+\z/.match?(value)
          key.failure("must be a valid email")
        end
      end
    end
  end
end
```

---

## Controllers

Thin HTTP adapters that delegate to operations:

```ruby
# app/web/controllers/sessions_controller.rb
# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    result = Operations::Users::Authenticate.new.call(
      email: params[:email_address],
      password: params[:password]
    )

    case result
    in Success(user)
      start_session(user)
      redirect_to root_path, notice: "Welcome back!"
    in Failure(:invalid_credentials)
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    in Failure([:validation_failed, errors])
      flash.now[:alert] = errors.values.flatten.first
      render :new, status: :unprocessable_entity
    end
  end
end
```

### Admin Controller Pattern

```ruby
# app/web/controllers/admin/incidents_controller.rb
# frozen_string_literal: true

module Web
  module Controllers
    module Admin
      # Handles HTTP requests for incidents
      class IncidentsController < Admin::BaseController
        def index
          incidents = incident_repo.all
          @incidents = parts_factory.wrap_many(incidents)
        end

        def show
          incident = incident_repo.find!(params[:id])
          @incident = parts_factory.wrap(incident)
        end

        def create
          result = Operations::Incidents::Create.new.call(
            incident_params,
            created_by: Current.user
          )

          case result
          in Success(incident)
            redirect_to admin_incident_path(incident.id), notice: "Incident created!"
          in Failure(errors)
            @errors = errors
            render :new, status: :unprocessable_entity
          end
        end

        private

        def incident_repo
          @incident_repo ||= AppContainer["repos.incident"]
        end

        def parts_factory
          @parts_factory ||= AppContainer["parts.factory"]
        end

        def incident_params
          params.require(:incident).permit(:name, :description, :bib_number, :race_id)
        end
      end
    end
  end
end
```

---

## Parts

Presentation decorators that wrap structs with view-specific logic:

### Base Part

```ruby
# app/web/parts/base.rb
# frozen_string_literal: true

module Web
  module Parts
    # Base class for all view parts
    class Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      # Delegate missing methods to the wrapped struct
      def method_missing(method, *args, &block)
        if value.respond_to?(method)
          value.public_send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        value.respond_to?(method) || super
      end

      def to_model
        value
      end

      def to_s
        value.to_s
      end

      def helpers
        ApplicationController.helpers
      end
    end
  end
end
```

### Part Factory

```ruby
# app/web/parts/factory.rb
# frozen_string_literal: true

module Web
  module Parts
    # Auto-wraps structs in their corresponding parts
    # Structs::Incident → Web::Parts::Incident
    class Factory
      def wrap(struct)
        return nil if struct.nil?
        part_class_for(struct).new(struct)
      end

      def wrap_many(structs)
        structs.map { |s| wrap(s) }
      end

      private

      def part_class_for(struct)
        part_name = struct.class.name.sub("Structs::", "").sub("Summary", "")
        "Web::Parts::#{part_name}".constantize
      rescue NameError
        Web::Parts::Base
      end
    end
  end
end
```

### Example Part

```ruby
# app/web/parts/incident.rb
# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for Incident
    class Incident < Base
      def status_badge
        case value.status
        when "pending"
          helpers.tag.span("Pending", class: "badge bg-yellow-100 text-yellow-800")
        when "reviewed"
          helpers.tag.span("Reviewed", class: "badge bg-blue-100 text-blue-800")
        when "official"
          helpers.tag.span("Official", class: "badge bg-green-100 text-green-800")
        else
          helpers.tag.span(value.status.titleize, class: "badge bg-gray-100 text-gray-800")
        end
      end

      def time_ago
        helpers.time_ago_in_words(value.reported_at) + " ago"
      end

      def dom_id
        "incident_#{value.id}"
      end

      def bib_display
        "##{value.bib_number}"
      end
    end
  end
end
```

---

## Broadcasters

Real-time Turbo Stream broadcasts, separated from business logic:

### Base Broadcaster

```ruby
# app/broadcasters/base_broadcaster.rb
# frozen_string_literal: true

# Base class for real-time broadcasters
class BaseBroadcaster
  include Import["parts.factory"]

  private

  def wrap(struct)
    parts_factory.wrap(struct)
  end

  def broadcast_prepend(stream:, target:, partial:, locals:)
    Turbo::StreamsChannel.broadcast_prepend_to(
      stream,
      target: target,
      partial: partial,
      locals: locals
    )
  end

  def broadcast_replace(stream:, target:, partial:, locals:)
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: target,
      partial: partial,
      locals: locals
    )
  end

  def broadcast_remove(stream:, target:)
    Turbo::StreamsChannel.broadcast_remove_to(
      stream,
      target: target
    )
  end
end
```

### Example Broadcaster

```ruby
# app/broadcasters/incident_broadcaster.rb
# frozen_string_literal: true

# Broadcasts real-time updates for Incident changes
class IncidentBroadcaster < BaseBroadcaster
  def created(incident)
    broadcast_prepend(
      stream: stream_name(incident.race_id),
      target: "incidents",
      partial: "admin/incidents/incident",
      locals: { incident: wrap(incident) }
    )
  end

  def updated(incident)
    broadcast_replace(
      stream: stream_name(incident.race_id),
      target: wrap(incident).dom_id,
      partial: "admin/incidents/incident",
      locals: { incident: wrap(incident) }
    )
  end

  def deleted(incident)
    broadcast_remove(
      stream: stream_name(incident.race_id),
      target: wrap(incident).dom_id
    )
  end

  private

  def stream_name(race_id)
    "race_#{race_id}_incidents"
  end
end
```

---

## Dependency Injection

### Container (`config/initializers/container.rb`)

```ruby
# frozen_string_literal: true

require "dry/container"
require "dry/auto_inject"

class AppContainer
  extend Dry::Container::Mixin

  # Repos (memoized - singleton per process)
  register "repos.user", memoize: true do
    UserRepo.new
  end

  register "repos.incident", memoize: true do
    IncidentRepo.new
  end

  register "repos.role", memoize: true do
    RoleRepo.new
  end

  # Parts
  namespace :parts do
    register "factory", memoize: true do
      Web::Parts::Factory.new
    end
  end

  # Broadcasters
  namespace :broadcasters do
    register "incident", memoize: true do
      IncidentBroadcaster.new
    end

    register "user", memoize: true do
      UserBroadcaster.new
    end
  end

  # Utilities
  register "logger" do
    Rails.logger
  end
end

# Global import helper
Import = Dry::AutoInject(AppContainer)
```

### Usage in Operations

```ruby
class MyOperation
  include Import["repos.user", "repos.incident", "logger"]

  def call
    logger.info("Finding user...")
    user = repos_user.find(1)
    # repos are injected as instance methods
  end
end
```

### Testing with Mocked Dependencies

```ruby
RSpec.describe Operations::Users::Authenticate do
  subject(:operation) { described_class.new(repos_user: mock_repo) }

  let(:mock_repo) { instance_double(UserRepo) }

  it "returns user on valid credentials" do
    allow(mock_repo).to receive(:authenticate)
      .with("test@example.com", "password")
      .and_return(user_struct)

    result = operation.call(email: "test@example.com", password: "password")
    expect(result).to be_success
  end
end
```

### Container Keys

```ruby
AppContainer["repos.user"]            # => UserRepo
AppContainer["repos.incident"]        # => IncidentRepo
AppContainer["parts.factory"]         # => Web::Parts::Factory
AppContainer["broadcasters.incident"] # => IncidentBroadcaster
AppContainer["broadcasters.user"]     # => UserBroadcaster
```

---

## Types

Shared type definitions (`lib/ismf_race_logger/types.rb`):

```ruby
# frozen_string_literal: true

require "dry-types"

module IsmfRaceLogger
  module Types
    include Dry.Types()

    # Common types
    Email = String.constrained(format: URI::MailTo::EMAIL_REGEXP)
    StrictString = Strict::String.constrained(min_size: 1)
    UUID = String.constrained(
      format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    )

    # User roles
    RoleName = Strict::String.enum(
      "var_operator",
      "national_referee",
      "international_referee",
      "jury_president",
      "referee_manager",
      "broadcast_viewer"
    )

    # Incident statuses
    IncidentStatus = Strict::String.enum("unofficial", "official")

    # Decision types
    DecisionType = Strict::String.enum(
      "pending",
      "penalty_applied",
      "rejected",
      "no_action"
    )

    # Race statuses
    RaceStatus = Strict::String.enum("upcoming", "active", "completed")

    # Bib number (1-9999)
    BibNumber = Coercible::Integer.constrained(gteq: 1, lteq: 9999)
  end
end
```

---

## Packwerk Boundaries

Packwerk enforces layer separation. Configuration files:

### Root (`package.yml`)

```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - app/db
  - app/operations
  - app/web
```

### DB Package (`app/db/package.yml`)

```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - "."  # For AR models
```

### Operations Package (`app/operations/package.yml`)

```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - "."
  - "app/db"
```

### Web Package (`app/web/package.yml`)

```yaml
enforce_dependencies: true
enforce_privacy: true
dependencies:
  - "."
  - "app/db"
  - "app/operations"
```

### Commands

```bash
# Check boundaries
docker compose exec app bundle exec packwerk check

# Update dependencies (for existing violations only)
docker compose exec app bundle exec packwerk update-todo
```

---

## Real-Time Architecture

### Data Flow for Real-Time Updates

```
1. User submits form
2. Controller calls Operation
3. Operation creates/updates via Repo
4. Operation calls Broadcaster
5. Broadcaster wraps struct in Part
6. Broadcaster renders partial with Part
7. Turbo Stream broadcasts to all subscribers
8. All connected clients see instant update
```

### Subscribing to Streams

```erb
<%# In your template %>
<%= turbo_stream_from "race_#{@race.id}_incidents" %>

<div id="incidents">
  <%= render partial: "incident", collection: @incidents %>
</div>
```

### Multi-User Collaboration

- All race officials subscribe to same stream
- Any update broadcasts to all
- Parts ensure consistent rendering
- No page refresh needed

---

## Turbo Native Support

### Variant Detection

```ruby
# app/web/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :set_variant

  private

  def set_variant
    request.variant = :turbo_native if turbo_native_app?
  end

  def turbo_native_app?
    request.user_agent&.include?("Turbo Native")
  end
end
```

### Template Variants

```
app/views/admin/incidents/
├── index.html.erb                    # Web version
├── index.turbo_native.html.erb       # Native override (optional)
├── _incident.html.erb                # Shared partial
└── _incident.turbo_native.html.erb   # Native partial (optional)
```

Rails automatically resolves:
- Web request → `index.html.erb`
- Turbo Native → `index.turbo_native.html.erb` (falls back to `index.html.erb`)

### Layout Variants

```
app/views/layouts/
├── application.html.erb              # Full web chrome
├── application.turbo_native.html.erb # Minimal native chrome
├── admin.html.erb
└── admin.turbo_native.html.erb
```

---

## Offline Sync Architecture

> **See [OFFLINE_SYNC_STRATEGY.md](OFFLINE_SYNC_STRATEGY.md) for complete implementation guide**

This application supports **bi-directional sync** between online (cloud) and offline (Raspberry Pi) deployments.

### System Modes

The same codebase runs in two modes:

```ruby
# config/application.rb
config.system_mode = ENV.fetch("SYSTEM_MODE", "cloud")
# Values: "cloud" or "offline_device"
```

| Mode | Environment | Purpose |
|------|-------------|---------|
| **cloud** | Production server | Full web interface, multi-user, ActionCable |
| **offline_device** | Raspberry Pi | Touch UI, single user, sync queue, offline-first |

---

### UUID-Based Distributed Identifiers

All syncable tables include `client_uuid`:

```ruby
# app/models/concerns/syncable.rb
module Syncable
  extend ActiveSupport::Concern
  
  included do
    before_validation :ensure_client_uuid, on: :create
  end
  
  private
  
  def ensure_client_uuid
    self.client_uuid ||= SecureRandom.uuid
  end
end

# Usage:
class Competition < ApplicationRecord
  include Syncable
  # Auto-generates client_uuid on create
end
```

**Key Principle:** Integer IDs are local-only. UUIDs are the distributed identifier.

---

### Data Categories

#### Reference Data (Created Once)

Created in ONE place only (cloud OR Pi, never both):

- Competitions, Stages, Races
- Race Locations, Race Types
- Athletes, Teams, Race Participations

**Sync:** Whoever creates → Other syncs

#### Operational Data (Merged)

Created in BOTH places simultaneously:

- Incidents
- Reports

**Sync:** Bi-directional with 3-layer deduplication

---

### Deduplication Layers

```ruby
# app/operations/sync/create_incident.rb
module Operations
  module Sync
    class CreateIncident
      def call(attrs)
        # Layer 1: UUID exact match
        existing = incident_repo.find_by_client_uuid(attrs[:client_uuid])
        return Success(existing) if existing && data_matches?(existing, attrs)
        return Failure([:conflict, "UUID exists with different data"]) if existing
        
        # Layer 2: Fingerprint match (auto-merge)
        fingerprint = IncidentFingerprintService.generate(attrs)
        mergeable = incident_repo.find_by_fingerprint(fingerprint)
        if mergeable
          merge_reports_to_incident(attrs, mergeable)
          return Success(mergeable)
        end
        
        # Layer 3: Create new
        incident_repo.create(attrs)
      end
    end
  end
end
```

---

### Sync API Pattern

All sync endpoints follow this pattern:

```ruby
# app/controllers/api/v1/sync_controller.rb
module Api
  module V1
    class SyncController < BaseController
      before_action :authenticate_device!
      
      def create_incidents
        results = params[:incidents].map do |incident_attrs|
          result = Operations::Sync::CreateIncident.new.call(incident_attrs)
          
          if result.success?
            { client_uuid: incident_attrs[:client_uuid], status: "created" }
          else
            { client_uuid: incident_attrs[:client_uuid], status: "conflict", error: result.failure }
          end
        end
        
        render json: { results: results }
      end
      
      private
      
      def authenticate_device!
        token = request.headers["Authorization"]&.remove("Bearer ")
        @current_device = DeviceRepo.new.find_by_token(token)
        head :unauthorized unless @current_device
      end
    end
  end
end
```

**Foreign Key Resolution:**

Sync API uses UUIDs for all foreign keys:

```ruby
# Client sends:
{
  "incident": {
    "client_uuid": "incident-123",
    "race_client_uuid": "race-456",  # UUID, not ID!
    "bib_number": 42
  }
}

# Server resolves:
race = Race.find_by!(client_uuid: attrs[:race_client_uuid])
incident = Incident.create!(race_id: race.id, ...)
```

---

### Sync Queue (Pi Only)

```ruby
# app/jobs/sync_queue_worker.rb
class SyncQueueWorker < ApplicationJob
  def perform
    return unless offline_device_mode?
    return unless network_available?
    
    SyncQueue.pending.find_each do |entry|
      SyncService.new.sync_entry(entry)
    rescue => e
      handle_error(entry, e)
    end
  end
  
  private
  
  def network_available?
    HTTP.timeout(2).get("#{server_url}/api/v1/sync/health").status.success?
  rescue
    false
  end
end
```

**Incremental Sync:**

Each record tracks its sync status:

```ruby
# sync_queue table
client_uuid | record_type | status    | retry_count
abc-123     | Incident    | pending   | 0
def-456     | Report      | synced    | 0
ghi-789     | Incident    | failed    | 3

# Only "pending" and "failed" (retry_count < 5) are synced
```

---

### Conflict Resolution

Conflicts flagged for manual admin review:

```ruby
# Admin UI shows:
SyncConflict.pending.each do |conflict|
  # Display:
  # - Cloud data vs Device data side-by-side
  # - Conflict type (decision_mismatch, etc)
  # - Resolution options: [Keep Cloud] [Keep Device] [Manual Override]
end

# Resolution operation:
Operations::Sync::ResolveConflict.new.call(
  conflict_id: conflict.id,
  resolution: "cloud_wins", # or "device_wins", "manual"
  user_id: current_user.id
)
```

---

### Container Registration

```ruby
# config/initializers/container.rb
class AppContainer
  extend Dry::Container::Mixin
  
  # Sync services (only in offline_device mode)
  if Rails.application.config.system_mode == "offline_device"
    register "services.sync" do
      SyncService.new
    end
    
    register "services.incident_fingerprint" do
      IncidentFingerprintService
    end
  end
end
```

---

## Performance Patterns

### Struct Type Selection

| Use Case | Struct Type | Speed |
|----------|-------------|-------|
| Single record | dry-struct (`Structs::User`) | Type-safe |
| Collections | Ruby Data (`Structs::UserSummary`) | 7x faster |

### Benchmark Results

```
                          user     system      total        real
AR Model instantiate: 0.015625   0.000000   0.015625 (  0.015698)
Data class:           0.000953   0.000000   0.000953 (  0.000956)
dry-struct:           0.007034   0.000000   0.007034 (  0.007040)
```

### When to Use What

- **List/index pages**: Ruby `Data` (summary structs)
- **Show/edit pages**: dry-struct (full validation)
- **Real-time updates**: Ruby `Data` (fast instantiation)
- **Form submissions**: dry-struct (type coercion)

---

## Testing Strategy

### Test Locations

```
spec/
├── db/
│   ├── repos/           # Repo queries
│   └── structs/         # Struct attributes/methods
├── models/              # AR associations/validations
├── operations/          # Business logic (integration)
├── requests/            # Controller/HTTP (full stack)
└── broadcasters/        # Real-time broadcasts
```

### Run Tests

```bash
# CRITICAL: Always use RAILS_ENV=test
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec

# Specific file
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb

# Specific line
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/sessions_spec.rb:25

# With documentation format
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format documentation
```

### Run by Layer

```bash
# Repo tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/db/repos/

# Operation tests
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/operations/

# Request specs
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/requests/
```

---

## Quick Reference

### Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Model | `User` | `app/models/user.rb` |
| Struct | `Structs::User` | `app/db/structs/user.rb` |
| Summary | `Structs::UserSummary` | `app/db/structs/user_summary.rb` |
| Repo | `UserRepo` | `app/db/repos/user_repo.rb` |
| Operation | `Operations::Users::Create` | `app/operations/users/create.rb` |
| Sync Operation | `Operations::Sync::CreateIncident` | `app/operations/sync/create_incident.rb` |
| Contract | `Operations::Contracts::CreateUser` | `app/operations/contracts/create_user.rb` |
| Controller | `Admin::UsersController` | `app/web/controllers/admin/users_controller.rb` |
| Sync API | `Api::V1::SyncController` | `app/controllers/api/v1/sync_controller.rb` |
| Part | `Web::Parts::User` | `app/web/parts/user.rb` |
| Broadcaster | `UserBroadcaster` | `app/broadcasters/user_broadcaster.rb` |
| Service | `IncidentFingerprintService` | `app/services/incident_fingerprint_service.rb` |

### Parts vs Structs

| Aspect | Struct | Part |
|--------|--------|------|
| Purpose | Domain data | View presentation |
| Methods | `admin?`, `active?` | `status_badge`, `formatted_date` |
| Location | `app/db/structs/` | `app/web/parts/` |
| Mutable | No (immutable) | No (wraps struct) |
| Used in | Operations, Repos | Templates, Broadcasters |

### Offline Sync Quick Reference

| Concept | Description |
|---------|-------------|
| **`client_uuid`** | Real distributed identifier (UUIDs), not integer IDs |
| **System Mode** | `SYSTEM_MODE=cloud` or `SYSTEM_MODE=offline_device` |
| **Reference Data** | Created once (cloud OR Pi), synced |
| **Operational Data** | Created in both, merged via 3-layer deduplication |
| **Layer 1** | UUID exact match (idempotent) |
| **Layer 2** | Fingerprint match (auto-merge) |
| **Layer 3** | Create new or flag conflict |

**Sync Endpoints:** `POST /api/v1/sync/incidents`, `POST /api/v1/sync/reports`, etc.

**See:** [OFFLINE_SYNC_STRATEGY.md](OFFLINE_SYNC_STRATEGY.md) for complete guide.

---

### File Creation Order

When creating a new feature:

1. Migration
2. Model
3. Struct(s)
4. Repo
5. Contract(s)
6. Operation(s)
7. Controller
8. Part
9. Views
10. Broadcaster (if real-time)
11. Tests

---

**Architecture Version**: 2.0
**Last Updated**: 2025
**Status**: Approved