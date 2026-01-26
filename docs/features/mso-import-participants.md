# Feature: MSO Import & Participant Models

## Overview

This feature adds the `Participant` model to track athletes/racers with bib numbers for each race, and implements MSO (timekeeper system) import functionality to sync the official start list before each race.

---

## Gap Analysis: Current Architecture

The current `architecture-overview.md` is **missing**:

1. **Participant/RaceParticipant model** - No way to track who is racing with what bib number
2. **Bib number on Report** - Reports don't capture which athlete the report is about
3. **MSO import integration** - No way to import the official start list from the timekeeper

### Current Report Model (Incomplete)

```ruby
# Current - Missing bib_number!
class Report < ApplicationRecord
  belongs_to :race
  belongs_to :incident, optional: true
  belongs_to :rule
  belongs_to :user
  belongs_to :race_location, optional: true
  has_one_attached :video
end
```

---

## Requirements Summary

### User Stories

1. **As a race administrator**, I need to import the start list from MSO so that referees have accurate bib numbers during the race.
2. **As a referee**, I need to select a bib number when creating a report so the incident is linked to the correct athlete.
3. **As a VAR operator**, I need to see athlete names alongside bib numbers so I can verify identity in video.
4. **As a jury president**, I need to see athlete status (racing, DNF, DNS, DSQ) to understand race context.

### Acceptance Criteria

- [ ] Participant model stores bib number, athlete info, and race status
- [ ] MSO import creates/updates participants from CSV/XML file
- [ ] Import handles incremental updates (status changes during race)
- [ ] Reports link to participants via bib number
- [ ] Bib selector shows only active participants
- [ ] Import can be triggered via UI or API
- [ ] Import history is tracked for audit

---

## Data Model

### New Models

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA MODEL                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐       ┌──────────────────┐       ┌───────────────┐   │
│  │    Race      │──────<│   Participant    │       │    Report     │   │
│  ├──────────────┤   1:N ├──────────────────┤       ├───────────────┤   │
│  │ id           │       │ id               │       │ id            │   │
│  │ name         │       │ race_id (FK)     │>──────│ participant_id│   │
│  │ status       │       │ bib_number       │       │ bib_number    │   │
│  └──────────────┘       │ athlete_name     │       │ race_id       │   │
│                         │ athlete_country  │       │ ...           │   │
│                         │ team_name        │       └───────────────┘   │
│                         │ category         │                           │
│                         │ status           │                           │
│                         │ start_time       │                           │
│                         │ finish_time      │                           │
│                         │ mso_id           │                           │
│                         └──────────────────┘                           │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      MsoImport (Audit Log)                        │  │
│  ├──────────────────────────────────────────────────────────────────┤  │
│  │ id | race_id | user_id | filename | status | stats | created_at │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Participant Model

#### Task 1.1: Create Participant Model
- **Owner**: Developer
- **Agent**: @model
- **File**: `app/models/participant.rb`
- **Migration**:
  ```ruby
  create_table :participants do |t|
    t.references :race, null: false, foreign_key: true
    t.integer :bib_number, null: false
    t.string :athlete_name, null: false
    t.string :athlete_first_name
    t.string :athlete_last_name
    t.string :athlete_country  # ISO 3166-1 alpha-3 (e.g., "SUI", "FRA")
    t.string :team_name
    t.string :category         # e.g., "Senior Men", "U23 Women"
    t.integer :status, default: 0  # enum: registered, racing, finished, dnf, dns, dsq
    t.datetime :start_time
    t.datetime :finish_time
    t.integer :rank            # Final position
    t.string :mso_id           # External ID from timekeeper
    t.jsonb :mso_data          # Raw data from MSO for reference

    t.timestamps
  end

  add_index :participants, [:race_id, :bib_number], unique: true
  add_index :participants, [:race_id, :status]
  add_index :participants, :mso_id
  add_index :participants, [:race_id, :athlete_country]
  ```
- **Model**:
  ```ruby
  class Participant < ApplicationRecord
    belongs_to :race
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
    validates :athlete_name, presence: true
    validates :race, presence: true
    
    scope :active, -> { where(status: [:registered, :racing]) }
    scope :can_report, -> { where(status: [:registered, :racing, :finished]) }
    scope :by_bib, -> { order(:bib_number) }
    scope :by_country, ->(country) { where(athlete_country: country) }
    
    # Full name helper
    def display_name
      "#{bib_number} - #{athlete_name}"
    end
    
    # For bib selector display
    def as_bib_json
      {
        number: bib_number,
        name: athlete_name,
        country: athlete_country,
        category: category,
        status: status
      }
    end
  end
  ```
- **Dependencies**: None

#### Task 1.2: Update Report Model with Participant Reference
- **Owner**: Developer
- **Agent**: @model
- **File**: `db/migrate/XXXXXX_add_participant_to_reports.rb`
- **Migration**:
  ```ruby
  add_reference :reports, :participant, foreign_key: true
  add_column :reports, :bib_number, :integer  # Denormalized for query performance
  add_index :reports, :bib_number
  ```
- **Update Model**:
  ```ruby
  class Report < ApplicationRecord
    belongs_to :race
    belongs_to :incident, optional: true
    belongs_to :rule, optional: true  # Make optional for quick create
    belongs_to :user
    belongs_to :race_location, optional: true
    belongs_to :participant, optional: true  # NEW
    
    has_one_attached :video
    
    # Auto-populate bib_number from participant
    before_validation :set_bib_number_from_participant
    
    validates :bib_number, presence: true
    
    private
    
    def set_bib_number_from_participant
      self.bib_number ||= participant&.bib_number
    end
  end
  ```
- **Dependencies**: Task 1.1

#### Task 1.3: Update Architecture Overview
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `docs/architecture-overview.md`
- **Details**: Add Participant model section between Race and Incident
- **Dependencies**: Task 1.2

#### Task 1.4: Write Participant Model Tests
- **Owner**: Developer
- **Agent**: @rspec
- **File**: `spec/models/participant_spec.rb`
- **Details**:
  - Test validations (bib uniqueness per race)
  - Test scopes (active, can_report, by_bib)
  - Test status transitions
  - Test as_bib_json output
- **Dependencies**: Task 1.1

---

### Phase 2: MSO Import Service

#### Task 2.1: Create MsoImport Audit Model
- **Owner**: Developer
- **Agent**: @model
- **File**: `app/models/mso_import.rb`
- **Migration**:
  ```ruby
  create_table :mso_imports do |t|
    t.references :race, null: false, foreign_key: true
    t.references :user, null: false, foreign_key: true  # Who triggered import
    t.string :filename, null: false
    t.string :file_type  # csv, xml, json
    t.integer :status, default: 0  # pending, processing, completed, failed
    t.jsonb :stats       # { created: 10, updated: 5, errors: 1, skipped: 0 }
    t.text :error_message
    t.jsonb :error_details  # Array of row-level errors
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
      "Created: #{s['created'] || 0}, Updated: #{s['updated'] || 0}, Errors: #{s['errors'] || 0}"
    end
  end
  ```
- **Dependencies**: Task 1.1

#### Task 2.2: Create MSO CSV Parser
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/mso/parser/csv.rb`
- **Details**:
  ```ruby
  # frozen_string_literal: true
  
  module Mso
    module Parser
      class Csv
        REQUIRED_HEADERS = %w[bib_number athlete_name].freeze
        OPTIONAL_HEADERS = %w[
          first_name last_name country team category
          start_time finish_time status mso_id
        ].freeze
        
        attr_reader :errors
        
        def initialize(file_content)
          @content = file_content
          @errors = []
        end
        
        def parse
          rows = CSV.parse(@content, headers: true, header_converters: :symbol)
          
          validate_headers!(rows.headers)
          return [] if @errors.any?
          
          rows.map.with_index(2) do |row, line_number|  # +2 for header row
            parse_row(row, line_number)
          end.compact
        end
        
        private
        
        def validate_headers!(headers)
          missing = REQUIRED_HEADERS - headers.map(&:to_s)
          if missing.any?
            @errors << "Missing required headers: #{missing.join(', ')}"
          end
        end
        
        def parse_row(row, line_number)
          bib = row[:bib_number]&.to_s&.strip
          name = row[:athlete_name]&.to_s&.strip
          
          if bib.blank?
            @errors << "Line #{line_number}: Missing bib_number"
            return nil
          end
          
          if name.blank?
            @errors << "Line #{line_number}: Missing athlete_name"
            return nil
          end
          
          {
            bib_number: bib.to_i,
            athlete_name: name,
            athlete_first_name: row[:first_name]&.strip,
            athlete_last_name: row[:last_name]&.strip,
            athlete_country: row[:country]&.strip&.upcase,
            team_name: row[:team]&.strip,
            category: row[:category]&.strip,
            start_time: parse_time(row[:start_time]),
            finish_time: parse_time(row[:finish_time]),
            status: parse_status(row[:status]),
            mso_id: row[:mso_id]&.strip
          }
        end
        
        def parse_time(value)
          return nil if value.blank?
          Time.zone.parse(value)
        rescue ArgumentError
          nil
        end
        
        def parse_status(value)
          return :registered if value.blank?
          
          case value.to_s.strip.downcase
          when 'racing', 'started', 'on_course' then :racing
          when 'finished', 'fin' then :finished
          when 'dnf' then :dnf
          when 'dns' then :dns
          when 'dsq', 'dq' then :dsq
          else :registered
          end
        end
      end
    end
  end
  ```
- **Dependencies**: Task 2.1

#### Task 2.3: Create MSO Import Operation (dry-monads)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/mso/operation/import.rb`
- **Details**:
  ```ruby
  # frozen_string_literal: true
  
  module Mso
    module Operation
      class Import
        include Dry::Monads[:result, :do]
        
        def call(race:, file:, user:, filename: nil)
          import_record = yield create_import_record(race, user, filename || file.original_filename)
          parsed_data = yield parse_file(file, import_record)
          stats = yield upsert_participants(race, parsed_data, import_record)
          yield complete_import(import_record, stats)
          
          # Broadcast to connected clients that bib list updated
          broadcast_update(race)
          
          Success(import_record.reload)
        end
        
        private
        
        def create_import_record(race, user, filename)
          import = MsoImport.create(
            race: race,
            user: user,
            filename: filename,
            status: :processing,
            started_at: Time.current
          )
          
          import.persisted? ? Success(import) : Failure(import.errors.full_messages)
        end
        
        def parse_file(file, import_record)
          content = file.respond_to?(:read) ? file.read : file
          parser = Parser::Csv.new(content)
          data = parser.parse
          
          if parser.errors.any?
            import_record.update(
              status: :failed,
              error_message: "Parse errors",
              error_details: parser.errors,
              completed_at: Time.current
            )
            return Failure(parser.errors)
          end
          
          Success(data)
        end
        
        def upsert_participants(race, data, import_record)
          stats = { created: 0, updated: 0, errors: 0, skipped: 0 }
          error_details = []
          
          data.each_with_index do |row, index|
            result = upsert_participant(race, row)
            
            case result
            when :created then stats[:created] += 1
            when :updated then stats[:updated] += 1
            when :skipped then stats[:skipped] += 1
            else
              stats[:errors] += 1
              error_details << { row: index + 2, error: result }
            end
          end
          
          import_record.update(error_details: error_details) if error_details.any?
          
          Success(stats)
        end
        
        def upsert_participant(race, row)
          participant = race.participants.find_or_initialize_by(bib_number: row[:bib_number])
          
          was_new = participant.new_record?
          
          participant.assign_attributes(
            athlete_name: row[:athlete_name],
            athlete_first_name: row[:athlete_first_name],
            athlete_last_name: row[:athlete_last_name],
            athlete_country: row[:athlete_country],
            team_name: row[:team_name],
            category: row[:category],
            start_time: row[:start_time],
            finish_time: row[:finish_time],
            status: row[:status],
            mso_id: row[:mso_id]
          )
          
          return :skipped unless participant.changed?
          
          if participant.save
            was_new ? :created : :updated
          else
            participant.errors.full_messages.join(", ")
          end
        end
        
        def complete_import(import_record, stats)
          import_record.update(
            status: :completed,
            stats: stats,
            completed_at: Time.current
          )
          
          Success(stats)
        end
        
        def broadcast_update(race)
          ParticipantsChannel.broadcast_to(race, {
            action: "participants_updated",
            count: race.participants.active.count,
            updated_at: Time.current.iso8601
          })
        rescue => e
          Rails.logger.warn "Failed to broadcast participant update: #{e.message}"
        end
      end
    end
  end
  ```
- **Dependencies**: Task 2.2

#### Task 2.4: Create MSO Import Job (Background)
- **Owner**: Developer
- **Agent**: @job
- **File**: `app/jobs/mso_import_job.rb`
- **Details**:
  ```ruby
  class MsoImportJob < ApplicationJob
    queue_as :imports
    
    def perform(import_id)
      import = MsoImport.find(import_id)
      return if import.completed? || import.failed?
      
      file_content = import.file.download
      
      result = Mso::Operation::Import.call(
        race: import.race,
        file: file_content,
        user: import.user,
        filename: import.filename
      )
      
      case result
      when Dry::Monads::Success
        Rails.logger.info "MSO Import #{import_id} completed: #{import.reload.summary}"
      when Dry::Monads::Failure
        Rails.logger.error "MSO Import #{import_id} failed: #{result.failure}"
      end
    end
  end
  ```
- **Dependencies**: Task 2.3

#### Task 2.5: Create Import Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/controllers/mso_imports_controller.rb`
- **Details**:
  ```ruby
  class MsoImportsController < ApplicationController
    before_action :set_race
    
    def index
      @imports = @race.mso_imports.order(created_at: :desc).limit(20)
      authorize @imports
    end
    
    def create
      authorize MsoImport
      
      unless params[:file].present?
        return render json: { error: "No file provided" }, status: :unprocessable_entity
      end
      
      import = @race.mso_imports.create!(
        user: current_user,
        filename: params[:file].original_filename,
        file: params[:file],
        status: :pending
      )
      
      # Run immediately for small files, async for large
      if params[:file].size < 100.kilobytes
        Mso::Operation::Import.call(
          race: @race,
          file: params[:file].read,
          user: current_user,
          filename: params[:file].original_filename
        )
        import.reload
      else
        MsoImportJob.perform_later(import.id)
      end
      
      respond_to do |format|
        format.html { redirect_to race_mso_imports_path(@race), notice: import.summary }
        format.json { render json: import }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("imports", import) }
      end
    end
    
    def show
      @import = @race.mso_imports.find(params[:id])
      authorize @import
    end
    
    private
    
    def set_race
      @race = Race.find(params[:race_id])
    end
  end
  ```
- **Dependencies**: Task 2.4

#### Task 2.6: Write MSO Import Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/mso/parser/csv_spec.rb`
  - `spec/components/mso/operation/import_spec.rb`
  - `spec/jobs/mso_import_job_spec.rb`
- **Details**:
  - Test CSV parsing with valid data
  - Test CSV parsing with missing headers
  - Test CSV parsing with invalid rows
  - Test upsert (create + update)
  - Test idempotent import (same file twice)
  - Test status mapping
  - Test job queuing and execution
- **Dependencies**: Task 2.5

---

### Phase 3: Bib Selector Integration

#### Task 3.1: Update BibSelector to Use Participants
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
      
      # Pre-load all active participants for client-side filtering
      def participants_json
        race.participants
            .can_report  # registered, racing, or finished
            .by_bib
            .map(&:as_bib_json)
            .to_json
      end
      
      def location_json
        { id: location.id, name: location.name }.to_json
      end
    end
  end
  ```
- **View**:
  ```erb
  <%# app/components/fop/bib_selector_component.html.erb %>
  <div data-controller="bib-selector"
       data-bib-selector-participants-value="<%= participants_json %>"
       data-bib-selector-location-value="<%= location_json %>"
       data-bib-selector-race-id-value="<%= race.id %>">
    
    <!-- Modal (hidden by default) -->
    <div data-bib-selector-target="modal" 
         class="fixed inset-0 bg-black/50 hidden z-50">
      <div class="bg-white rounded-t-xl fixed bottom-0 inset-x-0 max-h-[80vh] 
                  overflow-hidden flex flex-col safe-area-inset">
        
        <!-- Header -->
        <div class="bg-ismf-navy text-white px-4 py-3 flex justify-between items-center">
          <div>
            <h2 class="font-semibold">Select Bib Number</h2>
            <p class="text-sm text-white/70" data-bib-selector-target="locationName"></p>
          </div>
          <button data-action="bib-selector#closeModal" class="p-2">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        
        <!-- Search -->
        <div class="px-4 py-2 border-b">
          <input type="text" 
                 placeholder="Search by bib or name..."
                 data-bib-selector-target="search"
                 data-action="input->bib-selector#filter"
                 class="w-full px-4 py-3 border rounded-lg text-lg"
                 inputmode="numeric">
        </div>
        
        <!-- Recent Bibs -->
        <div class="px-4 py-2 border-b" data-bib-selector-target="recent">
          <span class="text-xs text-gray-500 uppercase tracking-wide">Recent</span>
          <div class="flex gap-2 mt-1" data-bib-selector-target="recentList"></div>
        </div>
        
        <!-- Bib Grid -->
        <div class="flex-1 overflow-y-auto p-4">
          <div class="grid grid-cols-4 fop-7:grid-cols-6 tablet:grid-cols-8 gap-2"
               data-bib-selector-target="grid">
            <!-- Rendered by Stimulus -->
          </div>
        </div>
      </div>
    </div>
  </div>
  ```
- **Dependencies**: Task 1.1, Phase 2

#### Task 3.2: Create ParticipantsChannel for Live Updates
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/channels/participants_channel.rb`
- **Details**:
  ```ruby
  class ParticipantsChannel < ApplicationCable::Channel
    def subscribed
      @race = Race.find(params[:race_id])
      stream_for @race
    end
  end
  ```
- **JavaScript**:
  ```javascript
  // When participants are updated (MSO import), refresh bib list
  participantsChannel.onParticipantsUpdated = (data) => {
    // Fetch fresh participant list via Turbo
    Turbo.visit(window.location.href, { action: "replace" })
    
    // Or just update the bib selector data attribute
    this.element.dataset.bibSelectorParticipantsValue = data.participants
  }
  ```
- **Dependencies**: Task 3.1

#### Task 3.3: Update Report Creation with Bib
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/reports/operation/create.rb`
- **Details**:
  ```ruby
  module Reports
    module Operation
      class Create
        include Dry::Monads[:result, :do]
        
        def call(params:, user:)
          validated = yield validate_params(params)
          participant = yield find_participant(validated)
          report = yield create_report(validated, participant, user)
          yield broadcast_report(report)
          
          Success(report)
        end
        
        private
        
        def validate_params(params)
          # Require: race_id, race_location_id, bib_number
          if params[:race_id].blank? || params[:bib_number].blank?
            return Failure("race_id and bib_number are required")
          end
          
          Success(params)
        end
        
        def find_participant(params)
          participant = Participant.find_by(
            race_id: params[:race_id],
            bib_number: params[:bib_number]
          )
          
          participant ? Success(participant) : Failure("Participant not found")
        end
        
        def create_report(params, participant, user)
          report = Report.create(
            race_id: params[:race_id],
            race_location_id: params[:race_location_id],
            participant: participant,
            bib_number: participant.bib_number,
            user: user
          )
          
          report.persisted? ? Success(report) : Failure(report.errors.full_messages)
        end
        
        def broadcast_report(report)
          IncidentsChannel.broadcast_to(report.race, {
            action: "report_created",
            report: ReportSerializer.new(report).as_json
          })
          
          Success(true)
        end
      end
    end
  end
  ```
- **Dependencies**: Task 1.2, Task 3.1

---

### Phase 4: MSO Import UI

#### Task 4.1: Create Import UI (Admin)
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `app/views/mso_imports/index.html.erb`
- **Details**:
  - File upload form (drag & drop)
  - Import history table
  - Status indicators
  - Error detail expansion
- **Dependencies**: Task 2.5

#### Task 4.2: Create Import API Endpoint
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/controllers/api/v1/mso_imports_controller.rb`
- **Details**:
  - Accept CSV/JSON via API
  - Return import status
  - Support webhook callback
- **Dependencies**: Task 2.5

---

## MSO CSV Format

### Required Format

```csv
bib_number,athlete_name,country,category,status
1,John Smith,USA,Senior Men,registered
2,Jean Dupont,FRA,Senior Men,registered
3,Maria Garcia,ESP,Senior Women,registered
...
```

### Optional Extended Format

```csv
bib_number,athlete_name,first_name,last_name,country,team,category,start_time,finish_time,status,mso_id
1,John Smith,John,Smith,USA,Team USA,Senior Men,2024-02-15T09:00:00,,,MSO-12345
2,Jean Dupont,Jean,Dupont,FRA,FFME,Senior Men,2024-02-15T09:01:00,2024-02-15T09:45:23,finished,MSO-12346
```

### Status Values

| MSO Value | Our Status |
|-----------|------------|
| (empty) | registered |
| started, racing, on_course | racing |
| finished, fin | finished |
| dnf | dnf |
| dns | dns |
| dsq, dq | dsq |

---

## Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RACE DATA FLOW                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐    CSV/XML    ┌─────────────────────┐               │
│  │  MSO System   │──────────────►│  MsoImportJob       │               │
│  │  (Timekeeper) │               │  - Parse file       │               │
│  └───────────────┘               │  - Upsert           │               │
│                                  │    participants     │               │
│                                  └──────────┬──────────┘               │
│                                             │                           │
│                                             ▼                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Race                                      │   │
│  │  ├── participants[] ◄── Bib numbers, athlete names, status      │   │
│  │  ├── race_locations[]                                           │   │
│  │  ├── incidents[]                                                │   │
│  │  └── reports[] ◄── Links to participant via bib_number         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────┐    Tap Location    ┌──────────────────────────┐   │
│  │  FOP Interface  │──────────────────► │  Bib Selector Modal      │   │
│  │  (7" / iPad)    │                    │  - Pre-loaded from       │   │
│  │                 │◄─ Select Bib ──────│    participants          │   │
│  │                 │                    │  - Client-side filter    │   │
│  └─────────────────┘                    │  - Recent bibs           │   │
│         │                               └──────────────────────────┘   │
│         │ Creates Report                                               │
│         ▼                                                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Report                                                          │   │
│  │  - race_id                                                       │   │
│  │  - race_location_id                                             │   │
│  │  - participant_id ◄── Links to athlete                          │   │
│  │  - bib_number ◄── Denormalized for quick access                 │   │
│  │  - user_id (reporter)                                           │   │
│  │  - video (attached later)                                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Multi-Device Considerations

### Bib Data Sync

When MSO import updates participants:
1. Server broadcasts via `ParticipantsChannel`
2. All connected devices receive update notification
3. Devices can either:
   - Soft reload (fetch new participant JSON)
   - Hard reload (full page refresh via Turbo)

### Offline Scenarios

1. **Device goes offline during race**:
   - Local participant list still works (pre-loaded)
   - Reports queue in IndexedDB
   - Sync when reconnected

2. **MSO import happens while device offline**:
   - Device has stale bib list
   - On reconnect, receives channel notification
   - Refreshes participant list

---

## Risks & Considerations

### Data Integrity

| Risk | Mitigation |
|------|------------|
| Bib number reuse across races | Unique constraint on (race_id, bib_number) |
| MSO import overwrites manual changes | Track `mso_id` separately, flag manual edits |
| Concurrent imports | Lock race during import, queue additional imports |

### Performance

| Concern | Solution |
|---------|----------|
| Large start list (500+ athletes) | Client-side filtering, pagination if needed |
| Frequent MSO syncs | Debounce imports, track unchanged rows |
| Slow Pi5 processing | Background job, progress updates |

---

## Success Metrics

1. **Import Speed**: < 5 seconds for 500 participants
2. **Bib Selection**: < 50ms to open modal with 500 participants
3. **Sync Reliability**: 99.9% successful imports
4. **Offline Support**: Reports created offline sync within 30s of reconnection

---

## Next Steps

1. Implement Participant model (Task 1.1)
2. Update Report model with participant reference (Task 1.2)
3. Build MSO import service (Phase 2)
4. Integrate with bib selector (Phase 3)
5. Add import UI (Phase 4)