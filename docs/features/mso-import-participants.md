# Feature: MSO Import & Athlete/Race Participation Models

## Overview

This feature adds the `Athlete` model (the person) and `RaceParticipation` model (bib assignment per race) to properly track athletes across competitions. It also supports **team races** (pairs: MM, MW, WW) where penalties apply to athletes and cascade to team results. MSO (timekeeper system) import syncs the active bib list via CSV.

---

## Key Constraints

| Constraint | Value | Impact |
|------------|-------|--------|
| **Max athletes per race** | 200 | Client-side bib grid trivial |
| **Active bibs vary by stage** | Quali=all (200), Sprint Finals=8 | Heat-based filtering |
| **Team races** | Pairs (MM, MW, WW) | Two athletes from same country share one bib |
| **Duplicate reports** | Allowed, grouped into incidents | No uniqueness constraint |
| **Stale reports** | Hidden after ~5 min | Background job cleanup |
| **Video upload** | Multiple files per report, V1 file upload only | No in-app recording |
| **MSO format** | CSV of athletes still active | Simple bib list import |
| **Country codes** | Known ISMF member countries only | Validated against list |
| **Bib display** | Bib number + 3-letter country code | Text for performance |
| **Team names** | Auto-generated from athlete names | DUPONT/GARCIA format |
| **License number** | Free text, optional | No format validation |
| **MSO format** | CSV of athletes still in play | Simple active bib list |

---

## Data Model

### Entity Relationship

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA MODEL                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      Athlete (The Person)                         │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ id            | Primary key                                       │  │
│  │ first_name    | String, required                                  │  │
│  │ last_name     | String, required                                  │  │
│  │ country       | String, validated against ISMF_COUNTRIES          │  │
│  │ license_number| String, optional, free text                       │  │
│  │ gender        | Enum: male, female                                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                    │                              │                     │
│                    │ 1:N                          │ 1:N                 │
│                    ▼                              ▼                     │
│  ┌────────────────────────────┐    ┌────────────────────────────────┐  │
│  │    RaceParticipation       │    │         Team (Pairs)           │  │
│  │    (Bib Assignment)        │    │                                │  │
│  ├────────────────────────────┤    ├────────────────────────────────┤  │
│  │ id                         │    │ id                             │  │
│  │ race_id          (FK)      │    │ race_id           (FK)         │  │
│  │ bib_number       (unique/race)│ │ bib_number        (unique/race)│  │
│  │ athlete_id       (FK, opt) │◄───│ athlete_1_id      (FK)         │  │
│  │ team_id          (FK, opt) │    │ athlete_2_id      (FK)         │  │
│  │ heat             (string)  │    │ team_type         (mm/mw/ww)   │  │
│  │ active_in_heat   (boolean) │    │ name              (optional)   │  │
│  │ status           (enum)    │    └────────────────────────────────┘  │
│  │ start_time       (datetime)│                                        │
│  │ finish_time      (datetime)│                                        │
│  │ rank             (integer) │                                        │
│  └─────────────┬──────────────┘                                        │
│                │                                                        │
│                │ 1:N                                                    │
│                ▼                                                        │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │                         Report                                      ││
│  ├────────────────────────────────────────────────────────────────────┤│
│  │ id                                                                  ││
│  │ race_id                    (FK)                                     ││
│  │ race_participation_id      (FK) ◄── Links to bib/athlete           ││
│  │ bib_number                 (denormalized for quick queries)        ││
│  │ race_location_id           (FK)                                     ││
│  │ user_id                    (FK, reporter)                           ││
│  │ incident_id                (FK, optional, when grouped)             ││
│  │ status                     (pending/reviewed/stale/archived)        ││
│  │ stale_at                   (datetime, +5 min from creation)         ││
│  │ videos                     (has_many_attached, multiple files)      ││
│  └────────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐│
│  │                       MsoImport (Audit Log)                         ││
│  ├────────────────────────────────────────────────────────────────────┤│
│  │ id | race_id | user_id | filename | status | stats | created_at    ││
│  └────────────────────────────────────────────────────────────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Bib Selector Display

**Performance choice**: Use 3-letter country codes (text) instead of emoji flags for consistent rendering and faster display.

**Team constraint**: Both athletes in a team are always from the same country.

**Team reports target specific athlete**: In team races, reports are created for a specific athlete (12.1 or 12.2), not the team. Gender is indicated by color:
- 🔵 **Blue** = Male
- 🔴 **Pink** = Female

```
┌─────────────────────────────────────────────────────────────────────────┐
│  BIB SELECTOR                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Individual Race (tap bib):                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                   │
│  │    12    │ │    34    │ │    56    │ │    78    │                   │
│  │   SUI    │ │   FRA    │ │   ITA    │ │   AUT    │                   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                   │
│                                                                         │
│  Team Race (tap specific athlete - 12.1 or 12.2):                       │
│                                                                         │
│  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐│
│  │ 12  FRA             │ │ 34  SUI             │ │ 56  ITA             ││
│  │ ┌────────┐┌────────┐│ │ ┌────────┐┌────────┐│ │ ┌────────┐┌────────┐││
│  │ │  12.1  ││  12.2  ││ │ │  34.1  ││  34.2  ││ │ │  56.1  ││  56.2  │││
│  │ │ BLUE   ││ PINK   ││ │ │ BLUE   ││ BLUE   ││ │ │ PINK   ││ PINK   │││
│  │ │ Male   ││ Female ││ │ │ Male   ││ Male   ││ │ │ Female ││ Female │││
│  │ └────────┘└────────┘│ │ └────────┘└────────┘│ │ └────────┘└────────┘││
│  │        MW           │ │        MM           │ │        WW           ││
│  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘│
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

Color Legend:
┌────────┐  ┌────────┐
│  BLUE  │  │  PINK  │
│  Male  │  │ Female │
└────────┘  └────────┘
```

### Penalty Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PENALTY CASCADE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Report created for bib 42 at Checkpoint 2                              │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────────┐                                                   │
│  │ RaceParticipation│  bib: 42, team_id: 7                             │
│  └────────┬────────┘                                                   │
│           │                                                             │
│           ▼                                                             │
│  ┌─────────────────┐                                                   │
│  │      Team       │  team_type: MW                                    │
│  │                 │  athlete_1: Jean (FRA) ← penalty applies here     │
│  │                 │  athlete_2: Maria (ESP)                           │
│  └─────────────────┘                                                   │
│           │                                                             │
│           ▼                                                             │
│  Team result affected by Jean's penalty                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Athlete Model

#### Task 1.1: Create Athlete Model
- **Owner**: Developer
- **Agent**: @model
- **Migration**:
  ```ruby
  create_table :athletes do |t|
    t.string :first_name, null: false
    t.string :last_name, null: false
    t.string :country, limit: 3  # ISO 3166-1 alpha-3
    t.string :license_number     # ISMF license, optional
    t.integer :gender, default: 0  # enum: male, female
    
    t.timestamps
  end
  
  add_index :athletes, :license_number, unique: true, where: "license_number IS NOT NULL"
  add_index :athletes, [:last_name, :first_name]
  add_index :athletes, :country
  ```
- **Model**:
  ```ruby
  class Athlete < ApplicationRecord
    has_many :race_participations, dependent: :destroy
    has_many :races, through: :race_participations
    has_many :teams_as_athlete_1, class_name: "Team", foreign_key: :athlete_1_id
    has_many :teams_as_athlete_2, class_name: "Team", foreign_key: :athlete_2_id
    
    enum :gender, { male: 0, female: 1 }
    
    validates :first_name, presence: true
    validates :last_name, presence: true
    validates :country, inclusion: { in: ISMF_COUNTRIES }, allow_blank: true
    validates :license_number, uniqueness: true, allow_nil: true
    
    def full_name
      "#{first_name} #{last_name}"
    end
    
    def display_name
      "#{last_name.upcase} #{first_name}"
    end
    
    def teams
      Team.where("athlete_1_id = ? OR athlete_2_id = ?", id, id)
    end
    
    # ISMF Member Countries (ISO 3166-1 alpha-3)
    # https://www.ismf-ski.org/member-federations
    ISMF_COUNTRIES = %w[
      AND ARG AUS AUT BEL BGR BIH CAN CHI CHN CRO CZE
      ESP FIN FRA GBR GER GRE HUN IND IRN ISR ITA JPN
      KAZ KOR LIE LTU MDA MKD NED NOR NZL POL POR ROU
      RSA RUS SLO SRB SUI SVK SWE TUR UKR USA
    ].freeze
  end
  ```
- **Dependencies**: None

#### Task 1.2: Create Team Model
- **Owner**: Developer
- **Agent**: @model
- **Migration**:
  ```ruby
  create_table :teams do |t|
    t.references :race, null: false, foreign_key: true
    t.integer :bib_number, null: false
    t.references :athlete_1, null: false, foreign_key: { to_table: :athletes }
    t.references :athlete_2, null: false, foreign_key: { to_table: :athletes }
    t.integer :team_type, null: false  # enum: mm, mw, ww
    t.string :name  # Optional custom name
    
    t.timestamps
  end
  
  add_index :teams, [:race_id, :bib_number], unique: true
  ```
- **Model**:
  ```ruby
  class Team < ApplicationRecord
    belongs_to :race
    belongs_to :athlete_1, class_name: "Athlete"
    belongs_to :athlete_2, class_name: "Athlete"
    has_one :race_participation, dependent: :destroy
    
    enum :team_type, { mm: 0, mw: 1, ww: 2 }  # men-men, mixed, women-women
    
    validates :bib_number, presence: true, uniqueness: { scope: :race_id }
    validate :team_type_matches_genders
    
    # Auto-generated team name: DUPONT/GARCIA
    def display_name
      "#{athlete_1.last_name.upcase}/#{athlete_2.last_name.upcase}"
    end
    
    # Both athletes must be from same country
    def country
      athlete_1.country
    end
    
    # Returns "SUI MM" or "FRA WW" for display
    def country_display
      "#{country} #{team_type.upcase}"
    end
    
    validate :athletes_same_country
    
    def athletes
      [athlete_1, athlete_2]
    end
    
    private
    
    def athletes_same_country
      if athlete_1.country != athlete_2.country
        errors.add(:base, "Both athletes must be from the same country")
      end
    end
    
    def team_type_matches_genders
      case team_type
      when "mm"
        unless athlete_1.male? && athlete_2.male?
          errors.add(:team_type, "MM team requires two male athletes")
        end
      when "ww"
        unless athlete_1.female? && athlete_2.female?
          errors.add(:team_type, "WW team requires two female athletes")
        end
      when "mw"
        genders = [athlete_1.gender, athlete_2.gender].sort
        unless genders == ["female", "male"]
          errors.add(:team_type, "MW team requires one male and one female athlete")
        end
      end
    end
  end
  ```
- **Dependencies**: Task 1.1

#### Task 1.3: Create RaceParticipation Model
- **Owner**: Developer
- **Agent**: @model
- **Migration**:
  ```ruby
  create_table :race_participations do |t|
    t.references :race, null: false, foreign_key: true
    t.integer :bib_number, null: false
    t.references :athlete, foreign_key: true  # For individual races
    t.references :team, foreign_key: true     # For team races
    t.string :heat                            # e.g., "final", "semi_1", "quali"
    t.boolean :active_in_heat, default: true
    t.integer :status, default: 0             # enum
    t.datetime :start_time
    t.datetime :finish_time
    t.integer :rank
    t.string :mso_id                          # External ID from timekeeper
    
    t.timestamps
  end
  
  add_index :race_participations, [:race_id, :bib_number], unique: true
  add_index :race_participations, [:race_id, :active_in_heat]
  add_index :race_participations, [:race_id, :status]
  add_index :race_participations, :mso_id
  ```
- **Model**:
  ```ruby
  class RaceParticipation < ApplicationRecord
    belongs_to :race
    belongs_to :athlete, optional: true  # For individual races
    belongs_to :team, optional: true     # For team races
    has_many :reports, dependent: :nullify
    
    enum :status, {
      registered: 0,  # Imported but race not started
      racing: 1,      # Currently on course
      finished: 2,    # Crossed finish line
      dnf: 3,         # Did Not Finish
      dns: 4,         # Did Not Start
      dsq: 5          # Disqualified
    }
    
    validates :bib_number, presence: true, 
              uniqueness: { scope: :race_id, message: "already exists in this race" }
    validate :athlete_or_team_present
    
    scope :active, -> { where(status: [:registered, :racing]) }
    scope :can_report, -> { where(status: [:registered, :racing, :finished]) }
    scope :in_current_heat, -> { where(active_in_heat: true) }
    scope :for_bib_selector, -> { can_report.in_current_heat.order(:bib_number) }
    scope :by_bib, -> { order(:bib_number) }
    
    # For bib selector display
    def display_name
      if team.present?
        team.display_name
      else
        athlete&.display_name || "Bib #{bib_number}"
      end
    end
    
    # Returns country code
    def country
      if team.present?
        team.country
      else
        athlete&.country
      end
    end
    
    # JSON for bib selector (optimized for performance)
    # For teams, returns two entries (one per athlete: 12.1, 12.2)
    def as_bib_json
      if team.present?
        # Team race: return array with both athletes
        [
          {
            bib: "#{bib_number}.1",
            bib_number: bib_number,
            athlete_position: 1,
            name: team.athlete_1.display_name,
            country: country,
            gender: team.athlete_1.gender,  # for color coding
            team_type: team.team_type,
            status: status
          },
          {
            bib: "#{bib_number}.2",
            bib_number: bib_number,
            athlete_position: 2,
            name: team.athlete_2.display_name,
            country: country,
            gender: team.athlete_2.gender,  # for color coding
            team_type: team.team_type,
            status: status
          }
        ]
      else
        # Individual race: single entry
        {
          bib: bib_number.to_s,
          bib_number: bib_number,
          athlete_position: nil,
          name: display_name,
          country: country,
          gender: athlete&.gender,
          team_type: nil,
          status: status
        }
      end
    end
    
    private
    
    def athlete_or_team_present
      if athlete_id.blank? && team_id.blank?
        errors.add(:base, "Must have either athlete or team")
      end
      if athlete_id.present? && team_id.present?
        errors.add(:base, "Cannot have both athlete and team")
      end
    end
  end
  ```
- **Dependencies**: Task 1.2

#### Task 1.4: Update Report Model
- **Owner**: Developer
- **Agent**: @model
- **Migration**:
  ```ruby
  add_reference :reports, :race_participation, foreign_key: true
  add_reference :reports, :athlete, foreign_key: true  # Specific athlete (for team races)
  add_column :reports, :bib_number, :integer  # Denormalized (e.g., 12)
  add_column :reports, :athlete_position, :integer  # 1 or 2 for team races (12.1, 12.2)
  add_column :reports, :status, :integer, default: 0
  add_column :reports, :stale_at, :datetime
  
  add_index :reports, :bib_number
  add_index :reports, :athlete_id
  add_index :reports, :status
  add_index :reports, :stale_at
  
  # Change from has_one_attached to has_many_attached for multiple videos
  # This is handled in model, not migration
  ```
- **Model**:
  ```ruby
  class Report < ApplicationRecord
    STALE_AFTER = 5.minutes
    
    belongs_to :race
    belongs_to :race_participation, optional: true
    belongs_to :athlete, optional: true  # Specific athlete (required for team races)
    belongs_to :incident, optional: true
    belongs_to :rule, optional: true
    belongs_to :user
    belongs_to :race_location, optional: true
    
    # Multiple video files per report
    has_many_attached :videos
    
    enum :status, {
      pending: 0,
      reviewed: 1,
      stale: 2,
      archived: 3
    }
    
    before_validation :set_bib_number_from_participation
    before_create :set_stale_at
    
    validates :bib_number, presence: true
    validate :athlete_required_for_team_race
    
    scope :active, -> { where(status: [:pending, :reviewed]) }
    scope :for_desktop_view, -> { active.order(created_at: :desc) }
    scope :needs_review, -> { pending.where("stale_at > ?", Time.current) }
    scope :became_stale, -> { pending.where("stale_at <= ?", Time.current) }
    
    def self.mark_stale!
      became_stale.update_all(status: :stale)
    end
    
    # Get the specific athlete this report is about
    def reported_athlete
      athlete || race_participation&.athlete
    end
    
    # Display bib with position for teams: "12.1" or just "12" for individual
    def bib_display
      if athlete_position.present?
        "#{bib_number}.#{athlete_position}"
      else
        bib_number.to_s
      end
    end
    
    private
    
    def set_bib_number_from_participation
      self.bib_number ||= race_participation&.bib_number
    end
    
    def athlete_required_for_team_race
      if race_participation&.team.present? && athlete_id.blank?
        errors.add(:athlete, "must be specified for team race reports")
      end
    end
    
    def set_stale_at
      self.stale_at ||= Time.current + STALE_AFTER
    end
  end
  ```
- **Dependencies**: Task 1.3

#### Task 1.5: Write Model Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/models/athlete_spec.rb`
  - `spec/models/team_spec.rb`
  - `spec/models/race_participation_spec.rb`
  - `spec/models/report_spec.rb`
- **Details**:
  - Test athlete validations and flag emoji
  - Test team type validation (MM/MW/WW)
  - Test race participation scopes (for_bib_selector)
  - Test report stale lifecycle
  - Test multiple video attachments
- **Dependencies**: Task 1.4

---

### Phase 2: MSO Import Service

#### Task 2.1: Create MsoImport Audit Model
- **Owner**: Developer
- **Agent**: @model
- **Migration**:
  ```ruby
  create_table :mso_imports do |t|
    t.references :race, null: false, foreign_key: true
    t.references :user, null: false, foreign_key: true
    t.string :filename, null: false
    t.integer :status, default: 0
    t.jsonb :stats
    t.text :error_message
    t.jsonb :error_details
    t.datetime :started_at
    t.datetime :completed_at
    
    t.timestamps
  end
  ```
- **Model**:
  ```ruby
  class MsoImport < ApplicationRecord
    belongs_to :race
    belongs_to :user
    
    has_one_attached :file
    
    enum :status, {
      pending: 0,
      processing: 1,
      completed: 2,
      failed: 3
    }
    
    validates :filename, presence: true
    
    def duration
      return nil unless started_at && completed_at
      completed_at - started_at
    end
    
    def summary
      return "Pending" if pending?
      return "Processing..." if processing?
      return error_message if failed?
      
      s = stats || {}
      "Athletes: #{s['athletes_created'] || 0} new, #{s['athletes_updated'] || 0} updated. " \
      "Bibs: #{s['participations_created'] || 0} new, #{s['participations_updated'] || 0} updated."
    end
  end
  ```
- **Dependencies**: Task 1.4

#### Task 2.2: Create MSO CSV Parser
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/mso/parser/csv.rb`
- **Expected CSV Format**:
  ```csv
  bib,first_name,last_name,country,gender,license,status
  1,Jean,Dupont,FRA,M,ISMF-12345,racing
  2,Maria,Garcia,ESP,F,ISMF-23456,racing
  3,Hans,Mueller,SUI,M,,racing
  ```
  
  For team races:
  ```csv
  bib,first_name_1,last_name_1,country_1,gender_1,first_name_2,last_name_2,country_2,gender_2,team_type,status
  1,Jean,Dupont,FRA,M,Maria,Garcia,ESP,F,MW,racing
  2,Hans,Mueller,SUI,M,Peter,Schmidt,GER,M,MM,racing
  ```
- **Details**:
  ```ruby
  module Mso
    module Parser
      class Csv
        INDIVIDUAL_HEADERS = %w[bib first_name last_name country].freeze
        TEAM_HEADERS = %w[bib first_name_1 last_name_1 country_1 gender_1
                          first_name_2 last_name_2 country_2 gender_2 team_type].freeze
        
        attr_reader :errors, :is_team_race
        
        def initialize(file_content)
          @content = file_content
          @errors = []
          @is_team_race = false
        end
        
        def parse
          rows = CSV.parse(@content, headers: true, header_converters: :symbol)
          
          @is_team_race = detect_team_race(rows.headers)
          validate_headers!(rows.headers)
          return [] if @errors.any?
          
          rows.map.with_index(2) do |row, line_number|
            parse_row(row, line_number)
          end.compact
        end
        
        private
        
        def detect_team_race(headers)
          headers.map(&:to_s).include?("first_name_1")
        end
        
        # ... parsing logic
      end
    end
  end
  ```
- **Dependencies**: Task 2.1

#### Task 2.3: Create MSO Import Operation
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/mso/operation/import.rb`
- **Details**:
  ```ruby
  module Mso
    module Operation
      class Import
        include Dry::Monads[:result, :do]
        
        def call(race:, file:, user:)
          import = yield create_import_record(race, user, file)
          parsed = yield parse_file(file, import)
          stats = yield upsert_data(race, parsed, import)
          yield complete_import(import, stats)
          
          Success(import.reload)
        end
        
        private
        
        def upsert_data(race, parsed_data, import)
          stats = { 
            athletes_created: 0, athletes_updated: 0,
            participations_created: 0, participations_updated: 0,
            teams_created: 0, errors: 0
          }
          
          parsed_data.each do |row|
            if import.is_team_race
              upsert_team_participation(race, row, stats)
            else
              upsert_individual_participation(race, row, stats)
            end
          end
          
          Success(stats)
        end
        
        def upsert_individual_participation(race, row, stats)
          # Find or create athlete by license or name+country
          athlete = find_or_create_athlete(row, stats)
          
          # Find or create race participation
          participation = race.race_participations.find_or_initialize_by(bib_number: row[:bib])
          participation.athlete = athlete
          participation.status = row[:status] || :registered
          participation.active_in_heat = true  # From MSO = currently active
          
          if participation.new_record?
            stats[:participations_created] += 1
          elsif participation.changed?
            stats[:participations_updated] += 1
          end
          
          participation.save!
        end
        
        def find_or_create_athlete(row, stats)
          athlete = if row[:license].present?
            Athlete.find_by(license_number: row[:license])
          end
          
          athlete ||= Athlete.find_by(
            first_name: row[:first_name],
            last_name: row[:last_name],
            country: row[:country]
          )
          
          if athlete
            stats[:athletes_updated] += 1 if athlete.update(
              country: row[:country],
              gender: parse_gender(row[:gender])
            )
          else
            athlete = Athlete.create!(
              first_name: row[:first_name],
              last_name: row[:last_name],
              country: row[:country],
              license_number: row[:license],
              gender: parse_gender(row[:gender])
            )
            stats[:athletes_created] += 1
          end
          
          athlete
        end
        
        def parse_gender(value)
          case value.to_s.upcase
          when "M", "MALE" then :male
          when "F", "FEMALE" then :female
          else :male  # Default
          end
        end
      end
    end
  end
  ```
- **Dependencies**: Task 2.2

#### Task 2.4: Write MSO Import Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/mso/parser/csv_spec.rb`
  - `spec/components/mso/operation/import_spec.rb`
- **Details**:
  - Test individual race CSV parsing
  - Test team race CSV parsing
  - Test athlete creation and update
  - Test participation creation
  - Test idempotent import (same file twice)
- **Dependencies**: Task 2.3

---

### Phase 3: Bib Selector Integration

#### Task 3.1: Create BibSelectorComponent
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/bib_selector_component.rb`
- **Details**:
  ```ruby
  module Fop
    class BibSelectorComponent < ViewComponent::Base
      attr_reader :race, :location
      
      def initialize(race:, location:)
        @race = race
        @location = location
      end
      
      # Pre-load participations for client-side rendering
      # Returns minimal JSON for performance
      # For team races, each participation returns 2 entries (one per athlete)
      def participations_json
        race.race_participations
            .for_bib_selector
            .includes(:athlete, team: [:athlete_1, :athlete_2])
            .flat_map(&:as_bib_json)  # flat_map because teams return arrays
            .to_json
      end
      
      def location_json
        { id: location.id, name: location.name }.to_json
      end
      
      def participation_count
        race.race_participations.for_bib_selector.count
      end
      
      def is_team_race?
        race.race_participations.joins(:team).exists?
      end
      
      # "8 athletes in Final" or "156 athletes"
      def participation_label
        count = participation_count
        heat = race.current_heat
        
        if heat.present? && heat != "all"
          "#{count} athletes in #{heat.titleize}"
        else
          "#{count} athletes"
        end
      end
    end
  end
  ```
- **View** (`app/components/fop/bib_selector_component.html.erb`):
  ```erb
  <div data-controller="bib-selector"
       data-bib-selector-participations-value="<%= participations_json %>"
       data-bib-selector-location-value="<%= location_json %>"
       data-bib-selector-race-id-value="<%= race.id %>">
    
    <div data-bib-selector-target="modal" 
         class="fixed inset-0 bg-black/50 hidden z-50">
      <div class="bg-white rounded-t-xl fixed bottom-0 inset-x-0 max-h-[85vh] 
                  overflow-hidden flex flex-col">
        
        <!-- Header -->
        <div class="bg-ismf-navy text-white px-4 py-3 flex justify-between items-center">
          <div>
            <h2 class="font-semibold text-lg">Select Bib</h2>
            <p class="text-sm text-white/70" data-bib-selector-target="locationName"></p>
          </div>
          <button data-action="bib-selector#closeModal" 
                  class="p-2 -mr-2 rounded-lg hover:bg-white/10">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        
        <!-- Search -->
        <div class="px-4 py-3 border-b bg-gray-50">
          <input type="text" 
                 placeholder="Search bib or name..."
                 data-bib-selector-target="search"
                 data-action="input->bib-selector#filter"
                 class="w-full px-4 py-3 border-2 rounded-xl text-lg font-medium"
                 inputmode="numeric"
                 autocomplete="off">
        </div>
        
        <!-- Bib Grid -->
        <div class="flex-1 overflow-y-auto p-4">
          <div class="grid grid-cols-4 fop-7:grid-cols-5 tablet:grid-cols-6 gap-3"
               data-bib-selector-target="grid">
            <!-- Rendered by Stimulus -->
          </div>
        </div>
      </div>
    </div>
  </div>
  ```
- **Dependencies**: Task 1.3

#### Task 3.2: Create Bib Selector Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/bib_selector_controller.js`
- **Details**:
  ```javascript
  import { Controller } from "@hotwired/stimulus"
  
  export default class extends Controller {
    static targets = ["modal", "grid", "search", "locationName"]
    static values = {
      participations: Array,
      location: Object,
      raceId: Number
    }
    
    connect() {
      this.participationsMap = new Map(
        this.participationsValue.map(p => [p.bib, p])
      )
    }
    
    openModal(event) {
      const locationId = event.currentTarget.dataset.locationId
      const locationName = event.currentTarget.dataset.locationName
      
      this.currentLocationId = locationId
      this.locationNameTarget.textContent = locationName
      
      this.renderGrid()
      this.modalTarget.classList.remove("hidden")
      this.searchTarget.focus()
    }
    
    closeModal() {
      this.modalTarget.classList.add("hidden")
      this.searchTarget.value = ""
    }
    
    renderGrid() {
      const html = this.participationsValue
        .filter(p => p.status !== "dnf" && p.status !== "dns" && p.status !== "dsq")
        .map(p => this.renderBibButton(p))
        .join("")
      
      this.gridTarget.innerHTML = html
    }
    
    renderBibButton(entry) {
      // Gender color: blue for male, pink for female
      const genderColor = entry.gender === "male" 
        ? "border-blue-400 bg-blue-50 hover:bg-blue-100" 
        : "border-pink-400 bg-pink-50 hover:bg-pink-100"
      
      const activeColor = entry.gender === "male"
        ? "active:bg-blue-500"
        : "active:bg-pink-500"
      
      // For teams, show position indicator
      const isTeam = entry.athlete_position != null
      const bibDisplay = isTeam ? entry.bib : entry.bib_number
      
      return `
        <button class="bib-button flex flex-col items-center justify-center 
                       min-h-[72px] p-2 border-2 
                       rounded-xl font-semibold transition-all
                       ${genderColor} ${activeColor}
                       active:scale-95 active:text-white"
                data-action="click->bib-selector#selectBib"
                data-bib="${entry.bib}"
                data-bib-number="${entry.bib_number}"
                data-athlete-position="${entry.athlete_position || ''}"
                data-gender="${entry.gender}">
          <span class="text-2xl font-bold">${bibDisplay}</span>
          <span class="text-sm text-gray-600">${entry.country}</span>
        </button>
      `
    }
    
    filter(event) {
      const query = event.target.value.toLowerCase()
      const buttons = this.gridTarget.querySelectorAll(".bib-button")
      
      buttons.forEach(btn => {
        const bib = btn.dataset.bib
        const participation = this.participationsMap.get(parseInt(bib))
        const matches = bib.includes(query) || 
                        participation.name.toLowerCase().includes(query) ||
                        participation.country?.toLowerCase().includes(query)
        btn.classList.toggle("hidden", !matches)
      })
    }
    
    async selectBib(event) {
      const btn = event.currentTarget
      const bibDisplay = btn.dataset.bib  // "12" or "12.1"
      const bibNumber = parseInt(btn.dataset.bibNumber)
      const athletePosition = btn.dataset.athletePosition 
        ? parseInt(btn.dataset.athletePosition) 
        : null
      const country = btn.closest('.bib-button')?.querySelector('.text-gray-600')?.textContent || ''
      
      // Immediate feedback
      this.showSuccessToast(bibDisplay, country)
      this.closeModal()
      
      // Save to recent
      this.saveRecentBib(bibDisplay)
      
      // Create report (optimistic, background sync)
      await this.createReport(bibNumber, athletePosition)
    }
    
    async createReport(bibNumber, athletePosition) {
      const report = {
        race_id: this.raceIdValue,
        race_location_id: this.currentLocationId,
        bib_number: bibNumber,
        athlete_position: athletePosition || null  // 1 or 2 for teams, null for individual
      }
      
      try {
        const response = await fetch("/reports", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
          },
          body: JSON.stringify({ report })
        })
        
        if (!response.ok) {
          this.showErrorToast("Failed to save report")
        }
      } catch (error) {
        // Queue for offline sync
        this.queueOfflineReport(report)
      }
    }
    
    showSuccessToast(bib, country) {
      // Dispatch event for toast controller
      this.dispatch("reportCreated", { 
        detail: { bib, country, message: `Report: bib ${bib} (${country})` }
      })
    }
  }
  ```
- **Dependencies**: Task 3.1

---

### Phase 4: Video Upload

#### Task 4.1: Create Video Upload Component
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/video_upload_component.rb`
- **Details**:
  - Accepts multiple files
  - Shows upload progress per file
  - Supports adding to existing report
  - File types: mp4, mov, webm
  - Max size: configurable (default 500MB)
- **Dependencies**: Task 1.4

#### Task 4.2: Create Add Video Operation
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/reports/operation/add_videos.rb`
- **Details**:
  ```ruby
  module Reports
    module Operation
      class AddVideos
        include Dry::Monads[:result, :do]
        
        MAX_FILE_SIZE = 500.megabytes
        ALLOWED_TYPES = %w[video/mp4 video/quicktime video/webm].freeze
        
        def call(report:, files:)
          validated_files = yield validate_files(files)
          yield attach_files(report, validated_files)
          
          Success(report.reload)
        end
        
        private
        
        def validate_files(files)
          errors = []
          
          files.each_with_index do |file, index|
            if file.size > MAX_FILE_SIZE
              errors << "File #{index + 1} exceeds maximum size (500MB)"
            end
            
            unless ALLOWED_TYPES.include?(file.content_type)
              errors << "File #{index + 1} has invalid type (must be MP4, MOV, or WebM)"
            end
          end
          
          errors.any? ? Failure(errors) : Success(files)
        end
        
        def attach_files(report, files)
          files.each do |file|
            report.videos.attach(file)
          end
          
          Success(true)
        rescue => e
          Failure(["Failed to attach files: #{e.message}"])
        end
      end
    end
  end
  ```
- **Dependencies**: Task 4.1

---

## MSO CSV Format

### Individual Race

```csv
bib,first_name,last_name,country,gender,license,status
1,Jean,DUPONT,FRA,M,ISMF-12345,racing
2,Maria,GARCIA,ESP,F,ISMF-23456,racing
3,Hans,MUELLER,SUI,M,,registered
4,Anna,ROSSI,ITA,F,ISMF-34567,finished
5,Erik,JOHANSSON,SWE,M,ISMF-45678,dnf
```

### Team Race (Pairs)

**Note**: Both athletes must be from the same country.

```csv
bib,first_name_1,last_name_1,gender_1,first_name_2,last_name_2,gender_2,country,team_type,status
1,Jean,DUPONT,M,Marie,MARTIN,F,FRA,MW,racing
2,Hans,MUELLER,M,Peter,SCHMIDT,M,SUI,MM,racing
3,Anna,ROSSI,F,Giulia,BIANCHI,F,ITA,WW,racing
```

### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `bib` | Yes | Bib number (unique per race) |
| `first_name` | Yes | Athlete first name |
| `last_name` | Yes | Athlete last name |
| `country` | Yes | ISO 3166-1 alpha-3 (SUI, FRA, ITA) |
| `gender` | No | M/F (defaults to M) |
| `license` | No | ISMF license number |
| `status` | No | registered/racing/finished/dnf/dns/dsq |

---

## Success Metrics

1. **MSO Import**: < 3 seconds for 200 athletes
2. **Bib Modal Open**: < 50ms (max 200 bibs)
3. **Report Creation**: < 100ms perceived
4. **Video Upload**: Progress shown, < 30s for 100MB file
5. **Offline Sync**: Reports sync within 30s of reconnection

---

## Next Steps

1. Create Athlete model with country, license, gender (Task 1.1)
2. Create Team model for pairs MM/MW/WW (Task 1.2)
3. Create RaceParticipation model for bib assignment (Task 1.3)
4. Update Report model with participation reference + multiple videos (Task 1.4)
5. Build MSO CSV import service (Phase 2)
6. Create bib selector with flags (Phase 3)
7. Add multi-file video upload (Phase 4)