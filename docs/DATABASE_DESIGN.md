# ISMF Race Logger - Database Design

> Hanami-Hybrid Architecture: Schema, Structs, Repos, and Types

This document defines the complete database schema and how each table maps to our Hanami-hybrid architecture layers.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Entity Relationship Diagram](#entity-relationship-diagram)
3. [Architecture Mapping](#architecture-mapping)
4. [Domain: Authentication](#domain-authentication)
5. [Domain: Competitions](#domain-competitions)
6. [Domain: Races](#domain-races)
7. [Domain: Athletes](#domain-athletes)
8. [Domain: Incidents & Reports](#domain-incidents--reports)
9. [Types Definition](#types-definition)
10. [Database Indexes](#database-indexes)
11. [Migrations Reference](#migrations-reference)

---

## Design Principles

### Performance Targets

| Operation | Target | Context |
|-----------|--------|---------|
| Report creation | < 100ms | FOP device tap |
| Bib selector load | < 50ms | 200 athletes max |
| Incident list refresh | < 100ms | Real-time Turbo Stream |

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary keys | `bigint` | Fast, sequential, Rails default |
| Offline sync | `client_uuid` column | Client-generated UUID for idempotent sync |
| Country codes | ISO 3166-1 alpha-3 | ISMF standard (SUI, FRA, ITA) |
| Enums | PostgreSQL native + Types | Type safety in Ruby |
| Soft deletes | None | Hard delete with audit log |

### Hanami-Hybrid Layer Mapping

For each table, we define:

| Layer | Purpose | Location |
|-------|---------|----------|
| **Model** | Associations only | `app/models/` |
| **Struct** | Immutable entity (single record) | `app/db/structs/` |
| **Summary** | Lightweight DTO (collections) | `app/db/structs/` |
| **Repo** | Queries, scopes, CRUD | `app/db/repos/` |
| **Types** | Enums, constraints | `lib/types.rb` |
| **Contract** | Validations | `app/operations/contracts/` |

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              ISMF RACE LOGGER - ERD                                  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌──────────────┐         ┌──────────────────┐         ┌──────────────────┐         │
│  │     User     │         │   Competition    │         │    RaceType      │         │
│  ├──────────────┤         ├──────────────────┤         ├──────────────────┤         │
│  │ id           │         │ id               │         │ id               │         │
│  │ email        │         │ name             │         │ name             │         │
│  │ name         │         │ place            │         │ description      │         │
│  │ role         │────┐    │ country          │         └────────┬─────────┘         │
│  │ country      │    │    │ start_date       │                  │                   │
│  └──────┬───────┘    │    │ end_date         │                  │                   │
│         │            │    └────────┬─────────┘                  │                   │
│         │            │             │                            │                   │
│  ┌──────┴───────┐    │    ┌────────┴─────────┐         ┌────────┴─────────┐         │
│  │   Session    │    │    │      Stage       │         │ RaceTypeLocation │         │
│  │   MagicLink  │    │    ├──────────────────┤         │    Template      │         │
│  └──────────────┘    │    │ id               │         └──────────────────┘         │
│                      │    │ competition_id   │                                      │
│                      │    │ name             │                                      │
│                      │    │ position         │                                      │
│                      │    └────────┬─────────┘                                      │
│                      │             │                                                │
│                      │    ┌────────┴─────────┐                                      │
│                      │    │      Race        │◄─────────────────────────────────┐   │
│                      │    ├──────────────────┤                                  │   │
│                      │    │ id               │         ┌──────────────────┐     │   │
│                      │    │ stage_id         │         │   RaceLocation   │     │   │
│                      │    │ race_type_id     │────────►├──────────────────┤     │   │
│                      │    │ name             │         │ id               │     │   │
│                      │    │ status           │         │ race_id          │     │   │
│                      │    │ scheduled_at     │         │ name             │     │   │
│                      │    └────────┬─────────┘         │ location_type    │     │   │
│                      │             │                   │ has_camera       │     │   │
│                      │             │                   └──────────────────┘     │   │
│                      │             │                                            │   │
│         ┌────────────┼─────────────┼────────────────────────────────────────┐   │   │
│         │            │             │                                        │   │   │
│         ▼            ▼             ▼                                        │   │   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │   │   │
│  │                         Athlete Domain                                │   │   │   │
│  ├──────────────────────────────────────────────────────────────────────┤   │   │   │
│  │                                                                       │   │   │   │
│  │  ┌──────────────┐       ┌──────────────────┐       ┌──────────────┐  │   │   │   │
│  │  │   Athlete    │       │      Team        │       │    Race      │  │   │   │   │
│  │  ├──────────────┤       ├──────────────────┤       │ Participation│  │   │   │   │
│  │  │ id           │◄──────│ athlete_1_id     │       ├──────────────┤  │   │   │   │
│  │  │ first_name   │◄──────│ athlete_2_id     │──────►│ id           │  │   │   │   │
│  │  │ last_name    │       │ race_id          │       │ race_id      │──┼───┘   │   │
│  │  │ country      │       │ bib_number       │       │ bib_number   │  │       │   │
│  │  │ gender       │       │ team_type        │       │ athlete_id   │◄─┼───────┘   │
│  │  │ license      │       └──────────────────┘       │ team_id      │  │           │
│  │  └──────────────┘                                  │ status       │  │           │
│  │         │                                          │ heat         │  │           │
│  │         │                                          └──────┬───────┘  │           │
│  │         │                                                 │          │           │
│  └─────────┼─────────────────────────────────────────────────┼──────────┘           │
│            │                                                 │                      │
│            │            ┌────────────────────────────────────┘                      │
│            │            │                                                           │
│            ▼            ▼                                                           │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                       Incident & Report Domain                                │   │
│  ├──────────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                               │   │
│  │  ┌──────────────────┐                    ┌──────────────────┐                │   │
│  │  │     Incident     │◄───────────────────│      Report      │                │   │
│  │  ├──────────────────┤    N:1             ├──────────────────┤                │   │
│  │  │ id               │                    │ id               │                │   │
│  │  │ race_id          │                    │ client_uuid      │                │   │
│  │  │ race_location_id │                    │ race_id          │                │   │
│  │  │ status           │                    │ incident_id      │                │   │
│  │  │ decision         │                    │ user_id          │ (reporter)     │   │
│  │  │ officialized_by  │                    │ race_location_id │                │   │
│  │  │ officialized_at  │                    │ race_particip_id │                │   │
│  │  │ decided_by       │                    │ athlete_id       │ (team races)   │   │
│  │  │ decided_at       │                    │ bib_number       │                │   │
│  │  │ reports_count    │                    │ description      │                │   │
│  │  └──────────────────┘                    │ video_clip       │                │   │
│  │                                          └──────────────────┘                │   │
│  │                                                                               │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Architecture Mapping

### Pattern for Each Table

```
┌─────────────────────────────────────────────────────────────────────┐
│  TABLE: incidents                                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Model (associations only)     → app/models/incident.rb             │
│  Struct (single record)        → app/db/structs/incident.rb         │
│  Summary (collections)         → app/db/structs/incident_summary.rb │
│  Repo (queries, CRUD)          → app/db/repos/incident_repo.rb      │
│  Types (enums)                 → lib/types.rb                       │
│  Contract (validations)        → app/operations/contracts/          │
│  Part (presentation)           → app/web/parts/incident.rb          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Domain: Authentication

### Table: users

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | Primary key |
| email_address | string | NOT NULL, UNIQUE | Login email |
| name | string | NOT NULL | Display name |
| password_digest | string | NOT NULL | bcrypt hash |
| role | enum | NOT NULL | User role |
| country | string(3) | | ISO 3166-1 alpha-3 |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `email_address` (unique), `role`

#### Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password
  belongs_to :role, optional: true  # If using separate Role table
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :reports, dependent: :nullify
  # NO validations, NO scopes, NO enums here
end
```

#### Struct

```ruby
# app/db/structs/user.rb
module Structs
  class User < Dry::Struct
    attribute :id, Types::Integer
    attribute :email_address, Types::Email
    attribute :name, Types::String
    attribute :role, Types::RoleName
    attribute :country, Types::String.optional
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    def admin?
      role.in?(%w[jury_president referee_manager])
    end

    def referee?
      role.in?(%w[national_referee international_referee])
    end

    def var_operator?
      role == "var_operator"
    end
  end
end
```

#### Summary

```ruby
# app/db/structs/user_summary.rb
module Structs
  UserSummary = Data.define(:id, :name, :email_address, :role, :country) do
    def display_name
      "#{name} (#{country})"
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/user_repo.rb
class UserRepo < DB::Repo
  returns_one :find_by_email, :authenticate
  returns_many :admins, :referees, :var_operators

  def find_by_email(email)
    find_by(email_address: email.downcase)
  end

  def authenticate(email, password)
    record = record_class.find_by(email_address: email.downcase)
    return nil unless record&.authenticate(password)
    build_struct(record)
  end

  def admins
    where(role: %w[jury_president referee_manager])
  end

  def referees
    where(role: %w[national_referee international_referee])
  end

  def var_operators
    where(role: "var_operator")
  end
end
```

---

### Table: sessions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| user_id | bigint | FK, NOT NULL | |
| ip_address | string | | Client IP |
| user_agent | string | | Browser/device |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

---

### Table: magic_links

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| user_id | bigint | FK, NOT NULL | |
| token | string | NOT NULL, UNIQUE | Secure token |
| expires_at | datetime | NOT NULL | Expiration time |
| used_at | datetime | | When consumed |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

---

## Domain: Competitions

### Table: competitions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| name | string | NOT NULL | Competition name |
| place | string | NOT NULL | Location/venue |
| country | string(3) | NOT NULL | ISO 3166-1 alpha-3 |
| description | text | | |
| start_date | date | NOT NULL | |
| end_date | date | NOT NULL | |
| webpage_url | string | | Official website |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `start_date`, `country`

#### Model

```ruby
# app/models/competition.rb
class Competition < ApplicationRecord
  has_many :stages, dependent: :destroy
  has_many :races, through: :stages
  has_one_attached :logo
end
```

#### Struct

```ruby
# app/db/structs/competition.rb
module Structs
  class Competition < Dry::Struct
    attribute :id, Types::Integer
    attribute :name, Types::String
    attribute :place, Types::String
    attribute :country, Types::CountryCode
    attribute :description, Types::String.optional
    attribute :start_date, Types::Date
    attribute :end_date, Types::Date
    attribute :webpage_url, Types::String.optional
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    def date_range
      "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
    end

    def ongoing?
      Date.current.between?(start_date, end_date)
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/competition_repo.rb
class CompetitionRepo < DB::Repo
  returns_many :upcoming, :ongoing, :past

  def upcoming
    where("start_date > ?", Date.current).order(:start_date)
  end

  def ongoing
    where("start_date <= ? AND end_date >= ?", Date.current, Date.current)
  end

  def past
    where("end_date < ?", Date.current).order(start_date: :desc)
  end
end
```

#### Contract

```ruby
# app/operations/contracts/create_competition.rb
module Operations::Contracts
  class CreateCompetition < Dry::Validation::Contract
    params do
      required(:name).filled(:string)
      required(:place).filled(:string)
      required(:country).filled(Types::CountryCode)
      required(:start_date).filled(:date)
      required(:end_date).filled(:date)
      optional(:description).maybe(:string)
      optional(:webpage_url).maybe(:string)
    end

    rule(:end_date, :start_date) do
      if values[:end_date] < values[:start_date]
        key(:end_date).failure("must be after start date")
      end
    end
  end
end
```

---

### Table: stages

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| competition_id | bigint | FK, NOT NULL | |
| name | string | NOT NULL | e.g., "Qualification", "Finals" |
| description | text | | |
| date | date | | Stage date |
| position | integer | NOT NULL, DEFAULT 0 | Sort order |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `competition_id`, `[competition_id, position]` (unique)

#### Model

```ruby
# app/models/stage.rb
class Stage < ApplicationRecord
  belongs_to :competition
  has_many :races, dependent: :destroy
end
```

---

## Domain: Races

### Table: race_types

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| name | string | NOT NULL, UNIQUE | sprint, vertical, individual, relay |
| description | text | | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Predefined values:** sprint, vertical, individual, relay

#### Model

```ruby
# app/models/race_type.rb
class RaceType < ApplicationRecord
  has_many :location_templates, class_name: "RaceTypeLocationTemplate", dependent: :destroy
  has_many :races, dependent: :restrict_with_error
end
```

---

### Table: race_type_location_templates

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_type_id | bigint | FK, NOT NULL | |
| name | string | NOT NULL | e.g., "Start", "Finish", "Platform 1" |
| location_type | enum | NOT NULL | referee, spectator, var |
| position | integer | NOT NULL, DEFAULT 0 | Sort order |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `[race_type_id, name]` (unique), `[race_type_id, position]` (unique)

---

### Table: races

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| stage_id | bigint | FK, NOT NULL | |
| race_type_id | bigint | FK, NOT NULL | |
| name | string | NOT NULL | |
| scheduled_at | datetime | | Start time |
| position | integer | NOT NULL, DEFAULT 0 | Sort order |
| status | enum | NOT NULL, DEFAULT scheduled | Race status |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `stage_id`, `race_type_id`, `status`, `[stage_id, position]` (unique)

#### Model

```ruby
# app/models/race.rb
class Race < ApplicationRecord
  belongs_to :stage
  belongs_to :race_type
  has_one :competition, through: :stage
  has_many :race_locations, dependent: :destroy
  has_many :race_participations, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :teams, dependent: :destroy
end
```

#### Struct

```ruby
# app/db/structs/race.rb
module Structs
  class Race < Dry::Struct
    attribute :id, Types::Integer
    attribute :stage_id, Types::Integer
    attribute :race_type_id, Types::Integer
    attribute :name, Types::String
    attribute :scheduled_at, Types::Time.optional
    attribute :position, Types::Integer
    attribute :status, Types::RaceStatus
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    def in_progress?
      status == "in_progress"
    end

    def completed?
      status == "completed"
    end

    def can_report?
      status.in?(%w[scheduled in_progress])
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/race_repo.rb
class RaceRepo < DB::Repo
  returns_many :active, :for_competition

  def active
    where(status: %w[scheduled in_progress]).order(:position)
  end

  def for_competition(competition_id)
    joins(:stage).where(stages: { competition_id: competition_id })
  end

  def in_progress
    where(status: "in_progress")
  end
end
```

---

### Table: race_locations

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_id | bigint | FK, NOT NULL | |
| name | string | NOT NULL | |
| location_type | enum | NOT NULL | referee, spectator, var |
| has_camera | boolean | DEFAULT false | Has video feed |
| camera_stream_url | string | | Video stream URL |
| from_template | boolean | DEFAULT false, NOT NULL | Auto-created from template |
| position | integer | NOT NULL, DEFAULT 0 | Sort order |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `race_id`, `[race_id, name]` (unique)

#### Model

```ruby
# app/models/race_location.rb
class RaceLocation < ApplicationRecord
  belongs_to :race
  has_many :reports, dependent: :nullify
  has_many :incidents, dependent: :nullify
end
```

---

## Domain: Athletes

### Table: athletes

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| first_name | string | NOT NULL | |
| last_name | string | NOT NULL | |
| country | string(3) | | ISO 3166-1 alpha-3 |
| license_number | string | UNIQUE (where not null) | ISMF license |
| gender | enum | NOT NULL, DEFAULT male | male, female |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `[last_name, first_name]`, `country`, `license_number` (unique, partial)

#### Model

```ruby
# app/models/athlete.rb
class Athlete < ApplicationRecord
  has_many :race_participations, dependent: :destroy
  has_many :races, through: :race_participations
  has_many :teams_as_athlete_1, class_name: "Team", foreign_key: :athlete_1_id
  has_many :teams_as_athlete_2, class_name: "Team", foreign_key: :athlete_2_id
  has_many :reports, dependent: :nullify
end
```

#### Struct

```ruby
# app/db/structs/athlete.rb
module Structs
  class Athlete < Dry::Struct
    attribute :id, Types::Integer
    attribute :first_name, Types::String
    attribute :last_name, Types::String
    attribute :country, Types::CountryCode.optional
    attribute :license_number, Types::String.optional
    attribute :gender, Types::Gender
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    def full_name
      "#{first_name} #{last_name}"
    end

    def display_name
      "#{last_name.upcase} #{first_name}"
    end

    def male?
      gender == "male"
    end

    def female?
      gender == "female"
    end
  end
end
```

#### Summary

```ruby
# app/db/structs/athlete_summary.rb
module Structs
  AthleteSummary = Data.define(:id, :first_name, :last_name, :country, :gender) do
    def display_name
      "#{last_name.upcase} #{first_name}"
    end

    def country_display
      "#{country} #{gender == 'male' ? '♂' : '♀'}"
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/athlete_repo.rb
class AthleteRepo < DB::Repo
  returns_one :find_by_license
  returns_many :search, :by_country

  def find_by_license(license)
    find_by(license_number: license)
  end

  def find_or_match(first_name:, last_name:, country:, license: nil)
    # Try license first
    return find_by_license(license) if license.present?

    # Fall back to name + country match
    find_by(first_name: first_name, last_name: last_name, country: country)
  end

  def search(query)
    where("last_name ILIKE :q OR first_name ILIKE :q", q: "%#{query}%")
      .order(:last_name, :first_name)
  end

  def by_country(country_code)
    where(country: country_code).order(:last_name)
  end
end
```

#### Contract

```ruby
# app/operations/contracts/create_athlete.rb
module Operations::Contracts
  class CreateAthlete < Dry::Validation::Contract
    params do
      required(:first_name).filled(:string)
      required(:last_name).filled(:string)
      optional(:country).maybe(Types::CountryCode)
      optional(:license_number).maybe(:string)
      required(:gender).filled(Types::Gender)
    end

    rule(:country) do
      if value.present? && !Types::ISMF_COUNTRIES.include?(value)
        key.failure("must be a valid ISMF country code")
      end
    end
  end
end
```

---

### Table: teams

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_id | bigint | FK, NOT NULL | |
| bib_number | integer | NOT NULL | |
| athlete_1_id | bigint | FK, NOT NULL | First team member |
| athlete_2_id | bigint | FK, NOT NULL | Second team member |
| team_type | enum | NOT NULL | mm, mw, ww |
| name | string | | Optional custom name |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `race_id`, `[race_id, bib_number]` (unique)

**Constraints:** Both athletes must be from the same country

#### Model

```ruby
# app/models/team.rb
class Team < ApplicationRecord
  belongs_to :race
  belongs_to :athlete_1, class_name: "Athlete"
  belongs_to :athlete_2, class_name: "Athlete"
  has_one :race_participation, dependent: :destroy
end
```

#### Struct

```ruby
# app/db/structs/team.rb
module Structs
  class Team < Dry::Struct
    attribute :id, Types::Integer
    attribute :race_id, Types::Integer
    attribute :bib_number, Types::BibNumber
    attribute :athlete_1, Structs::Athlete
    attribute :athlete_2, Structs::Athlete
    attribute :team_type, Types::TeamType
    attribute :name, Types::String.optional
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # Auto-generated: DUPONT/GARCIA
    def display_name
      name || "#{athlete_1.last_name.upcase}/#{athlete_2.last_name.upcase}"
    end

    # Both athletes same country
    def country
      athlete_1.country
    end

    def athletes
      [athlete_1, athlete_2]
    end
  end
end
```

#### Contract

```ruby
# app/operations/contracts/create_team.rb
module Operations::Contracts
  class CreateTeam < Dry::Validation::Contract
    params do
      required(:race_id).filled(:integer)
      required(:bib_number).filled(:integer, gt?: 0)
      required(:athlete_1_id).filled(:integer)
      required(:athlete_2_id).filled(:integer)
      required(:team_type).filled(Types::TeamType)
      optional(:name).maybe(:string)
    end

    rule(:athlete_1_id, :athlete_2_id) do
      if values[:athlete_1_id] == values[:athlete_2_id]
        key(:athlete_2_id).failure("must be different from athlete 1")
      end
    end
  end
end
```

---

### Table: race_participations

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_id | bigint | FK, NOT NULL | |
| bib_number | integer | NOT NULL | |
| athlete_id | bigint | FK | For individual races |
| team_id | bigint | FK | For team races |
| heat | string | | e.g., "final", "semi_1", "quali" |
| active_in_heat | boolean | DEFAULT true | Currently racing |
| status | enum | DEFAULT registered | Participation status |
| start_time | datetime | | |
| finish_time | datetime | | |
| rank | integer | | Final position |
| mso_id | string | | External timekeeper ID |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `[race_id, bib_number]` (unique), `[race_id, active_in_heat]`, `[race_id, status]`, `mso_id`

**Constraint:** Must have either athlete_id OR team_id, not both

#### Model

```ruby
# app/models/race_participation.rb
class RaceParticipation < ApplicationRecord
  belongs_to :race
  belongs_to :athlete, optional: true
  belongs_to :team, optional: true
  has_many :reports, dependent: :nullify
end
```

#### Struct

```ruby
# app/db/structs/race_participation.rb
module Structs
  class RaceParticipation < Dry::Struct
    attribute :id, Types::Integer
    attribute :race_id, Types::Integer
    attribute :bib_number, Types::BibNumber
    attribute :athlete, Structs::Athlete.optional
    attribute :team, Structs::Team.optional
    attribute :heat, Types::String.optional
    attribute :active_in_heat, Types::Bool
    attribute :status, Types::ParticipationStatus
    attribute :start_time, Types::Time.optional
    attribute :finish_time, Types::Time.optional
    attribute :rank, Types::Integer.optional

    def display_name
      team&.display_name || athlete&.display_name || "Bib #{bib_number}"
    end

    def country
      team&.country || athlete&.country
    end

    def team_race?
      team.present?
    end
  end
end
```

#### Summary (for bib selector)

```ruby
# app/db/structs/race_participation_summary.rb
module Structs
  RaceParticipationSummary = Data.define(
    :id, :bib_number, :display_name, :country, :gender, :team_type, :status, :active_in_heat
  ) do
    def can_report?
      status.in?(%w[registered racing finished]) && active_in_heat
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/race_participation_repo.rb
class RaceParticipationRepo < DB::Repo
  returns_many :for_bib_selector, :active, :by_bib

  def for_bib_selector(race_id)
    where(race_id: race_id)
      .where(status: %w[registered racing finished])
      .where(active_in_heat: true)
      .includes(:athlete, team: [:athlete_1, :athlete_2])
      .order(:bib_number)
  end

  def active(race_id)
    where(race_id: race_id, status: %w[registered racing])
  end

  def by_bib(race_id, bib_number)
    find_by(race_id: race_id, bib_number: bib_number)
  end

  def find_or_create_for_import(race_id:, bib_number:, athlete: nil, team: nil)
    find_by(race_id: race_id, bib_number: bib_number) ||
      create(race_id: race_id, bib_number: bib_number, athlete_id: athlete&.id, team_id: team&.id)
  end
end
```

---

## Domain: Incidents & Reports

### Design Principles

1. **Reports are observations** - No status/decision on reports
2. **Incidents are cases** - All status/decision logic here
3. **Two-level status** - Unofficial (VAR/Referee) → Official (Jury President)
4. **Offline support** - `client_uuid` for idempotent sync

```
┌─────────────────────────────────────────────────────────────────────────┐
│  WORKFLOW                                                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  FOP DEVICE (Referee)                                                    │
│  ════════════════════                                                    │
│  1. Tap bib #34 → Report created                                         │
│  2. Incident auto-created (1:1)                                          │
│  3. Status: UNOFFICIAL                                                   │
│  4. Response: < 100ms                                                    │
│                                                                          │
│       ↓                                                                  │
│                                                                          │
│  DESKTOP (VAR Operator)                                                  │
│  ══════════════════════                                                  │
│  5. See incident in real-time (Turbo Stream)                             │
│  6. Review video evidence                                                │
│  7. Can MERGE incidents (move reports to single incident)                │
│  8. Status: still UNOFFICIAL                                             │
│                                                                          │
│       ↓                                                                  │
│                                                                          │
│  DESKTOP (Jury President)                                                │
│  ════════════════════════                                                │
│  9. Review incident                                                      │
│  10. OFFICIALIZE → Status: OFFICIAL                                      │
│  11. Make DECISION:                                                      │
│      • Apply Penalty (decision: penalty_applied)                         │
│      • Reject (decision: rejected)                                       │
│      • No Action (decision: no_action)                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### Table: incidents

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_id | bigint | FK, NOT NULL | |
| race_location_id | bigint | FK | Where it occurred |
| status | enum | NOT NULL, DEFAULT unofficial | Lifecycle status |
| decision | enum | NOT NULL, DEFAULT pending | Jury decision |
| description | text | | |
| officialized_at | datetime | | When made official |
| officialized_by | bigint | FK (users) | Jury president |
| decided_at | datetime | | When decision made |
| decided_by | bigint | FK (users) | Decision maker |
| reports_count | integer | DEFAULT 0 | Counter cache |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `race_id`, `race_location_id`, `status`, `decision`, `[race_id, status]`

#### Model

```ruby
# app/models/incident.rb
class Incident < ApplicationRecord
  belongs_to :race
  belongs_to :race_location, optional: true
  belongs_to :officialized_by_user, class_name: "User", foreign_key: :officialized_by, optional: true
  belongs_to :decided_by_user, class_name: "User", foreign_key: :decided_by, optional: true
  has_many :reports, dependent: :destroy
end
```

#### Struct

```ruby
# app/db/structs/incident.rb
module Structs
  class Incident < Dry::Struct
    attribute :id, Types::Integer
    attribute :race_id, Types::Integer
    attribute :race_location_id, Types::Integer.optional
    attribute :status, Types::IncidentStatus
    attribute :decision, Types::DecisionType
    attribute :description, Types::String.optional
    attribute :officialized_at, Types::Time.optional
    attribute :officialized_by, Types::Integer.optional
    attribute :decided_at, Types::Time.optional
    attribute :decided_by, Types::Integer.optional
    attribute :reports_count, Types::Integer
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    def unofficial?
      status == "unofficial"
    end

    def official?
      status == "official"
    end

    def pending?
      decision == "pending"
    end

    def can_officialize?
      unofficial? && reports_count.positive?
    end

    def can_decide?
      official? && pending?
    end

    def display_type
      reports_count == 1 ? "Report" : "Incident"
    end
  end
end
```

#### Summary

```ruby
# app/db/structs/incident_summary.rb
module Structs
  IncidentSummary = Data.define(
    :id, :race_id, :status, :decision, :reports_count, :created_at, :bib_number, :location_name
  ) do
    def unofficial?
      status == "unofficial"
    end

    def official?
      status == "official"
    end

    def display_type
      reports_count == 1 ? "Report" : "Incident"
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/incident_repo.rb
class IncidentRepo < DB::Repo
  returns_many :for_race, :unofficial, :pending_decision, :recent

  def for_race(race_id)
    where(race_id: race_id).order(created_at: :desc)
  end

  def unofficial(race_id = nil)
    scope = where(status: "unofficial")
    scope = scope.where(race_id: race_id) if race_id
    scope.order(created_at: :desc)
  end

  def official(race_id = nil)
    scope = where(status: "official")
    scope = scope.where(race_id: race_id) if race_id
    scope.order(created_at: :desc)
  end

  def pending_decision(race_id = nil)
    scope = where(status: "official", decision: "pending")
    scope = scope.where(race_id: race_id) if race_id
    scope.order(created_at: :desc)
  end

  def decided(race_id = nil)
    scope = where(status: "official").where.not(decision: "pending")
    scope = scope.where(race_id: race_id) if race_id
    scope.order(decided_at: :desc)
  end

  def recent(race_id, limit: 20)
    where(race_id: race_id).order(created_at: :desc).limit(limit)
  end

  def with_reports
    includes(:reports)
  end
end
```

#### Contract

```ruby
# app/operations/contracts/officialize_incident.rb
module Operations::Contracts
  class OfficializeIncident < Dry::Validation::Contract
    params do
      required(:incident_id).filled(:integer)
      required(:user_id).filled(:integer)
    end
  end
end

# app/operations/contracts/decide_incident.rb
module Operations::Contracts
  class DecideIncident < Dry::Validation::Contract
    params do
      required(:incident_id).filled(:integer)
      required(:user_id).filled(:integer)
      required(:decision).filled(Types::DecisionType.exclude("pending"))
    end
  end
end
```

---

### Table: reports

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| client_uuid | uuid | NOT NULL, UNIQUE | For offline sync |
| race_id | bigint | FK, NOT NULL | |
| incident_id | bigint | FK, NOT NULL | Always belongs to incident |
| user_id | bigint | FK, NOT NULL | Reporter |
| race_location_id | bigint | FK | Where reported from |
| race_participation_id | bigint | FK | Bib/entry lookup |
| athlete_id | bigint | FK | Specific athlete (team races) |
| bib_number | integer | NOT NULL | Denormalized for queries |
| athlete_position | integer | | 1 or 2 for team races |
| description | text | | |
| video_clip | jsonb | | {start_time, end_time} |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `client_uuid` (unique), `race_id`, `incident_id`, `user_id`, `bib_number`, `created_at`

**Note:** Reports have NO STATUS - they are observations only. Status lives on Incident.

#### Model

```ruby
# app/models/report.rb
class Report < ApplicationRecord
  belongs_to :race
  belongs_to :incident, counter_cache: true
  belongs_to :user
  belongs_to :race_location, optional: true
  belongs_to :race_participation, optional: true
  belongs_to :athlete, optional: true
  has_many_attached :videos
end
```

#### Struct

```ruby
# app/db/structs/report.rb
module Structs
  class Report < Dry::Struct
    attribute :id, Types::Integer
    attribute :client_uuid, Types::UUID
    attribute :race_id, Types::Integer
    attribute :incident_id, Types::Integer
    attribute :user_id, Types::Integer
    attribute :race_location_id, Types::Integer.optional
    attribute :race_participation_id, Types::Integer.optional
    attribute :athlete_id, Types::Integer.optional
    attribute :bib_number, Types::BibNumber
    attribute :athlete_position, Types::Integer.optional
    attribute :description, Types::String.optional
    attribute :video_clip, Types::Hash.optional
    attribute :created_at, Types::Time
    attribute :updated_at, Types::Time

    # For display: "12" or "12.1" for teams
    def bib_display
      athlete_position ? "#{bib_number}.#{athlete_position}" : bib_number.to_s
    end
  end
end
```

#### Repo

```ruby
# app/db/repos/report_repo.rb
class ReportRepo < DB::Repo
  returns_one :find_by_client_uuid
  returns_many :for_incident, :for_race, :by_bib, :recent

  def find_by_client_uuid(uuid)
    find_by(client_uuid: uuid)
  end

  def for_incident(incident_id)
    where(incident_id: incident_id).order(created_at: :desc)
  end

  def for_race(race_id)
    where(race_id: race_id).order(created_at: :desc)
  end

  def by_bib(race_id, bib_number)
    where(race_id: race_id, bib_number: bib_number).order(created_at: :desc)
  end

  def recent(race_id, since: 1.hour.ago)
    where(race_id: race_id).where("created_at > ?", since).order(created_at: :desc)
  end

  def by_user(user_id)
    where(user_id: user_id).order(created_at: :desc)
  end

  # Idempotent create for offline sync
  def create_idempotent(attributes)
    existing = find_by_client_uuid(attributes[:client_uuid])
    return existing if existing

    create(attributes)
  end
end
```

#### Contract

```ruby
# app/operations/contracts/create_report.rb
module Operations::Contracts
  class CreateReport < Dry::Validation::Contract
    params do
      required(:race_id).filled(:integer)
      required(:user_id).filled(:integer)
      required(:bib_number).filled(:integer, gt?: 0)
      optional(:client_uuid).filled(:string)
      optional(:race_location_id).maybe(:integer)
      optional(:race_participation_id).maybe(:integer)
      optional(:athlete_id).maybe(:integer)
      optional(:athlete_position).maybe(:integer, included_in?: [1, 2])
      optional(:description).maybe(:string)
      optional(:video_clip).maybe(:hash)
    end

    rule(:video_clip) do
      next unless value.is_a?(Hash)
      start_time = value["start_time"] || value[:start_time]
      end_time = value["end_time"] || value[:end_time]

      if start_time && end_time && start_time >= end_time
        key.failure("start_time must be before end_time")
      end
    end
  end
end
```

---

### Table: rules

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| number | string | NOT NULL, UNIQUE | Rule number (e.g., "3.4.2") |
| title | string | NOT NULL | Short title |
| description | text | | Full rule text |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

**Indexes:** `number` (unique)

---

### Table: mso_imports (Audit Log)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK | |
| race_id | bigint | FK, NOT NULL | |
| user_id | bigint | FK, NOT NULL | Who imported |
| filename | string | NOT NULL | Original filename |
| status | enum | DEFAULT pending | Import status |
| stats | jsonb | | Import statistics |
| error_message | text | | Error if failed |
| error_details | jsonb | | Detailed errors |
| started_at | datetime | | |
| completed_at | datetime | | |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

---

## Types Definition

```ruby
# lib/types.rb
# frozen_string_literal: true

require "dry-types"

module IsmfRaceLogger
  module Types
    include Dry.Types()

    # Basic types
    Email = String.constrained(format: URI::MailTo::EMAIL_REGEXP)
    UUID = String.constrained(format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    BibNumber = Integer.constrained(gt: 0, lteq: 999)

    # User roles
    RoleName = String.enum(
      "national_referee",
      "international_referee",
      "var_operator",
      "jury_president",
      "referee_manager",
      "broadcast_viewer"
    )

    # Gender
    Gender = String.enum("male", "female")

    # Team types
    TeamType = String.enum("mm", "mw", "ww")

    # Race status
    RaceStatus = String.enum("scheduled", "in_progress", "completed", "cancelled")

    # Location types
    LocationType = String.enum("referee", "spectator", "var")

    # Participation status
    ParticipationStatus = String.enum(
      "registered",
      "racing",
      "finished",
      "dnf",
      "dns",
      "dsq"
    )

    # Incident status (two-level system)
    IncidentStatus = String.enum("unofficial", "official")

    # Decision types
    DecisionType = String.enum(
      "pending",
      "penalty_applied",
      "rejected",
      "no_action"
    )

    # MSO import status
    ImportStatus = String.enum("pending", "processing", "completed", "failed")

    # ISMF Member Countries (ISO 3166-1 alpha-3)
    ISMF_COUNTRIES = %w[
      AND ARG AUS AUT BEL BGR BIH CAN CHI CHN CRO CZE
      ESP FIN FRA GBR GER GRE HUN IND IRN ISR ITA JPN
      KAZ KOR LIE LTU MDA MKD NED NOR NZL POL POR ROU
      RSA RUS SLO SRB SUI SVK SWE TUR UKR USA
    ].freeze

    CountryCode = String.constrained(
      format: /\A[A-Z]{3}\z/,
      included_in: ISMF_COUNTRIES
    )
  end
end

# Alias for convenience
Types = IsmfRaceLogger::Types
```

---

## Database Indexes

### Critical for Performance

```ruby
# Reports - fast creation and lookup
add_index :reports, :client_uuid, unique: true
add_index :reports, :race_id
add_index :reports, :bib_number
add_index :reports, :created_at

# Incidents - real-time dashboard
add_index :incidents, [:race_id, :status]
add_index :incidents, [:race_id, :created_at]

# Race Participations - bib selector
add_index :race_participations, [:race_id, :bib_number], unique: true
add_index :race_participations, [:race_id, :active_in_heat, :status]

# Athletes - search
add_index :athletes, [:last_name, :first_name]
add_index :athletes, :country
add_index :athletes, :license_number, unique: true, where: "license_number IS NOT NULL"
```

---

## Migrations Reference

### Order of Creation

1. `users` (no dependencies)
2. `sessions`, `magic_links` (depends on users)
3. `race_types` (no dependencies)
4. `race_type_location_templates` (depends on race_types)
5. `competitions` (no dependencies)
6. `stages` (depends on competitions)
7. `races` (depends on stages, race_types)
8. `race_locations` (depends on races)
9. `athletes` (no dependencies)
10. `teams` (depends on races, athletes)
11. `race_participations` (depends on races, athletes, teams)
12. `incidents` (depends on races, race_locations, users)
13. `reports` (depends on races, incidents, users, race_locations, race_participations, athletes)
14. `rules` (no dependencies)
15. `mso_imports` (depends on races, users)

---

## Summary

This document defines the complete database schema for the ISMF Race Logger, mapped to our Hanami-hybrid architecture:

| Tables | 15 |
|--------|-----|
| Structs | 10+ |
| Summaries | 5+ |
| Repos | 10+ |
| Types/Enums | 12 |

All validations, scopes, and business logic are in their proper Hanami layers - NOT in ActiveRecord models.