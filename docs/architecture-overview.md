# Architecture Overview

This document provides a detailed overview of the architecture and models for the ISMF race logging system, integrating users, roles, competitions, races, locations, incidents, reports, and authorization via Pundit.

---

## Project Structure

```
app/
├── models/                           # ActiveRecord models
├── services/                         # Business logic (dry-monads)
│   ├── competitions/
│   │   ├── create_from_template.rb   # Competitions::CreateFromTemplate
│   │   └── duplicate.rb              # Competitions::Duplicate
│   ├── incidents/
│   │   ├── create.rb                 # Incidents::Create
│   │   └── officialize.rb            # Incidents::Officialize
│   ├── reports/
│   │   ├── create.rb                 # Reports::Create
│   │   └── attach_to_incident.rb     # Reports::AttachToIncident
│   └── races/
│       ├── start.rb                  # Races::Start
│       └── complete.rb               # Races::Complete
├── contracts/                        # dry-validation (if needed)
│   └── competitions/
│       └── create.rb                 # Contracts::Competitions::Create
├── policies/                         # Pundit authorization
│   ├── application_policy.rb
│   ├── competition_policy.rb
│   ├── incident_policy.rb
│   └── ...
└── controllers/

spec/
├── models/
├── services/
│   ├── competitions/
│   │   ├── create_from_template_spec.rb
│   │   └── duplicate_spec.rb
│   └── ...
└── policies/
```

---

## Recommended Models

### **1. User**

```ruby
# == Schema Information
#
# Table name: users
#
# id              :bigint           not null, primary key
# name            :string           not null
# email           :string           not null, unique
# password_digest :string           not null
# role            :enum             values: [:national_referee, :international_referee, :var_operator, :jury_president, :referee_manager, :broadcast_viewer]
# country         :string
# created_at      :datetime         not null
# updated_at      :datetime         not null
#
class User < ApplicationRecord
  # Rails 8.1 Authentication
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :reports, dependent: :nullify

  # Role enum (replaces separate Role model for simplicity)
  enum :role, {
    national_referee: "national_referee",
    international_referee: "international_referee",
    var_operator: "var_operator",
    jury_president: "jury_president",
    referee_manager: "referee_manager",
    broadcast_viewer: "broadcast_viewer"
  }, prefix: true

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true

  # Normalizations (Rails 7.1+)
  normalizes :email, with: ->(email) { email.strip.downcase }

  # Scopes
  scope :referees, -> { where(role: %w[national_referee international_referee]) }
  scope :var_operators, -> { where(role: "var_operator") }
  scope :admins, -> { where(role: %w[jury_president referee_manager]) }
  scope :ordered, -> { order(:name) }

  # Role check methods
  def has_role?(*role_names)
    role_names.map(&:to_s).include?(role)
  end

  def var_operator?
    role_var_operator?
  end

  def referee?
    role_national_referee? || role_international_referee?
  end

  def national_referee?
    role_national_referee?
  end

  def international_referee?
    role_international_referee?
  end

  def jury_president?
    role_jury_president?
  end

  def referee_manager?
    role_referee_manager?
  end

  def broadcast_viewer?
    role_broadcast_viewer?
  end

  def admin?
    jury_president? || referee_manager?
  end

  # Generate magic link token for passwordless login
  def generate_magic_link!
    magic_links.valid.update_all(used_at: Time.current) # Invalidate old links
    magic_links.create!(
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 15.minutes.from_now
    )
  end
end
```

### **1a. Session**

```ruby
# == Schema Information
#
# Table name: sessions
#
# id         :bigint           not null, primary key
# user_id    :bigint           not null, foreign_key
# token      :string           not null, unique
# ip_address :string
# user_agent :string
# created_at :datetime         not null
# updated_at :datetime         not null
#
class Session < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true

  before_create :generate_token

  private

  def generate_token
    loop do
      self.token = SecureRandom.urlsafe_base64(32)
      break unless Session.exists?(token: token)
    end
  end
end
```

### **1b. MagicLink**

```ruby
# == Schema Information
#
# Table name: magic_links
#
# id         :bigint           not null, primary key
# user_id    :bigint           not null, foreign_key
# token      :string           not null, unique
# expires_at :datetime         not null
# used_at    :datetime
# created_at :datetime         not null
# updated_at :datetime         not null
#
class MagicLink < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end

  def used?
    used_at.present?
  end

  def consume!
    return false if expired? || used?

    update!(used_at: Time.current)
    true
  end
end
```

### **2. CompetitionTemplate**

```ruby
# == Schema Information
#
# Table name: competition_templates
#
# id          :bigint           not null, primary key
# name        :string           not null, unique
# description :text
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class CompetitionTemplate < ApplicationRecord
  has_many :stage_templates, dependent: :destroy
  has_many :competition_template_race_types, dependent: :destroy
  has_many :race_types, through: :competition_template_race_types

  validates :name, presence: true, uniqueness: true

  # Scopes
  scope :ordered, -> { order(:name) }
end
```

### **2a. StageTemplate**

```ruby
# == Schema Information
#
# Table name: stage_templates
#
# id                      :bigint           not null, primary key
# competition_template_id :bigint           not null, foreign_key
# name                    :string           not null
# description             :text
# position                :integer          not null, default: 0
# created_at              :datetime         not null
# updated_at              :datetime         not null
#
class StageTemplate < ApplicationRecord
  belongs_to :competition_template
  has_many :race_templates, dependent: :destroy

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :competition_template_id }

  # Scopes
  scope :ordered, -> { order(:position) }
end
```

### **2b. RaceTemplate**

```ruby
# == Schema Information
#
# Table name: race_templates
#
# id                :bigint           not null, primary key
# stage_template_id :bigint           not null, foreign_key
# race_type_id      :bigint           not null, foreign_key
# name              :string           not null
# position          :integer          not null, default: 0
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
class RaceTemplate < ApplicationRecord
  belongs_to :stage_template
  belongs_to :race_type

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :stage_template_id }

  # Scopes
  scope :ordered, -> { order(:position) }
end
```

### **2c. CompetitionTemplateRaceType**

```ruby
# == Schema Information
#
# Table name: competition_template_race_types
#
# id                      :bigint           not null, primary key
# competition_template_id :bigint           not null, foreign_key
# race_type_id            :bigint           not null, foreign_key
# created_at              :datetime         not null
# updated_at              :datetime         not null
#
class CompetitionTemplateRaceType < ApplicationRecord
  belongs_to :competition_template
  belongs_to :race_type

  validates :race_type_id, uniqueness: { scope: :competition_template_id }
end
```

### **3. Competition**

```ruby
# == Schema Information
#
# Table name: competitions
#
# id          :bigint           not null, primary key
# name        :string           not null
# place       :string           not null
# country     :string           not null
# description :text
# start_date  :date             not null
# end_date    :date             not null
# webpage_url :string
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class Competition < ApplicationRecord
  has_many :stages, dependent: :destroy
  has_many :races, through: :stages

  has_one_attached :logo

  validates :name, presence: true
  validates :place, presence: true
  validates :country, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  # Scopes
  scope :ordered, -> { order(:start_date) }
  scope :upcoming, -> { where("start_date > ?", Date.current).order(:start_date) }
  scope :ongoing, -> { where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  scope :past, -> { where("end_date < ?", Date.current).order(start_date: :desc) }

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date < start_date
  end
end
```

### **4. Stage**

```ruby
# == Schema Information
#
# Table name: stages
#
# id             :bigint           not null, primary key
# competition_id :bigint           not null, foreign_key
# name           :string           not null
# description    :text
# date           :date
# position       :integer          not null, default: 0
# created_at     :datetime         not null
# updated_at     :datetime         not null
#
class Stage < ApplicationRecord
  belongs_to :competition
  has_many :races, dependent: :destroy

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :competition_id }

  # Scopes
  scope :ordered, -> { order(:position) }

  # Examples: "Qualification", "Semi-Finals", "Finals"
end
```

### **5. RaceType**

```ruby
# == Schema Information
#
# Table name: race_types
#
# id          :bigint           not null, primary key
# name        :string           not null, unique
# description :text
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class RaceType < ApplicationRecord
  has_many :location_templates, class_name: "RaceTypeLocationTemplate", dependent: :destroy
  has_many :races, dependent: :restrict_with_error
  has_many :race_templates, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true

  # Scopes
  scope :ordered, -> { order(:name) }

  # Predefined race types:
  # - sprint (default locations: start, finish, top, walk, platform_1, platform_2)
  # - vertical (default locations: start, finish, checkpoint_1, checkpoint_2)
  # - individual (default locations: start, finish, transition_1, transition_2)
  # - relay (default locations: start, finish, exchange_zone, transition)
end
```

### **6. RaceTypeLocationTemplate**

```ruby
# == Schema Information
#
# Table name: race_type_location_templates
#
# id            :bigint           not null, primary key
# race_type_id  :bigint           not null, foreign_key
# name          :string           not null
# location_type :enum             values: [:referee, :spectator, :var]
# position      :integer          not null, default: 0
# created_at    :datetime         not null
# updated_at    :datetime         not null
#
class RaceTypeLocationTemplate < ApplicationRecord
  belongs_to :race_type

  enum :location_type, {
    referee: "referee",
    spectator: "spectator",
    var: "var"
  }

  validates :name, presence: true, uniqueness: { scope: :race_type_id }
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :race_type_id }

  # Scopes
  scope :ordered, -> { order(:position) }
end
```

### **7. Race**

```ruby
# == Schema Information
#
# Table name: races
#
# id           :bigint           not null, primary key
# stage_id     :bigint           not null, foreign_key
# race_type_id :bigint           not null, foreign_key
# name         :string           not null
# scheduled_at :datetime
# position     :integer          not null, default: 0
# status       :enum             values: [:scheduled, :in_progress, :completed, :cancelled]
# created_at   :datetime         not null
# updated_at   :datetime         not null
#
class Race < ApplicationRecord
  belongs_to :stage
  belongs_to :race_type
  has_many :race_locations, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_many :reports, dependent: :destroy

  has_one :competition, through: :stage

  enum :status, {
    scheduled: "scheduled",
    in_progress: "in_progress",
    completed: "completed",
    cancelled: "cancelled"
  }, default: :scheduled

  validates :name, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :stage_id }

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :active, -> { where(status: [:scheduled, :in_progress]) }

  after_create :copy_locations_from_template

  private

  # Automatically copy default locations from RaceType template
  def copy_locations_from_template
    race_type.location_templates.ordered.each do |template|
      race_locations.create!(
        name: template.name,
        location_type: template.location_type,
        from_template: true,
        position: template.position
      )
    end
  end
end
```

### **8. RaceLocation**

```ruby
# == Schema Information
#
# Table name: race_locations
#
# id                :bigint           not null, primary key
# race_id           :bigint           not null, foreign_key
# name              :string           not null
# location_type     :enum             values: [:referee, :spectator, :var]
# has_camera        :boolean          default: false
# camera_stream_url :string
# from_template     :boolean          default: false, null: false
# position          :integer          not null, default: 0
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
class RaceLocation < ApplicationRecord
  belongs_to :race
  has_many :reports, dependent: :nullify
  has_many :incidents, dependent: :nullify

  enum :location_type, {
    referee: "referee",
    spectator: "spectator",
    var: "var"
  }

  validates :name, presence: true, uniqueness: { scope: :race_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :with_camera, -> { where(has_camera: true) }
  scope :from_template, -> { where(from_template: true) }
  scope :custom, -> { where(from_template: false) }
end
```

### **9. Incident**

```ruby
# == Schema Information
#
# Table name: incidents
#
# id                :bigint           not null, primary key
# race_id           :bigint           not null, foreign_key
# race_location_id  :bigint           foreign_key
# description       :text
# status            :integer          not null, default: 0 (unofficial)
# decision          :integer          not null, default: 0 (pending)
# description       :text             optional
# officialized_at   :datetime         optional
# officialized_by   :bigint           optional (user_id)
# decided_at        :datetime         optional
# decided_by        :bigint           optional (user_id)
# reports_count     :integer          default: 0 (counter cache)
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
# Two-Level Status System:
# - Level 1 (status): unofficial → official (lifecycle)
# - Level 2 (decision): pending → penalty_applied/rejected/no_action (only when official)
#
class Incident < ApplicationRecord
  # ═══════════════════════════════════════════════════════════════════
  # ASSOCIATIONS
  # ═══════════════════════════════════════════════════════════════════
  belongs_to :race
  belongs_to :race_location, optional: true
  belongs_to :officialized_by_user, class_name: "User",
             foreign_key: :officialized_by, optional: true
  belongs_to :decided_by_user, class_name: "User",
             foreign_key: :decided_by, optional: true

  has_many :reports, dependent: :destroy

  # ═══════════════════════════════════════════════════════════════════
  # ENUMS - Two-Level Status System
  # ═══════════════════════════════════════════════════════════════════

  # Level 1: Lifecycle status (who is responsible)
  # - unofficial: Being reviewed by VAR/Referee
  # - official: Confirmed by Jury President, ready for decision
  enum :status, {
    unofficial: 0,
    official: 1
  }

  # Level 2: Decision (only meaningful when official)
  # - pending: Awaiting jury decision
  # - penalty_applied: Penalty enforced
  # - rejected: No violation found
  # - no_action: Acknowledged, no penalty
  enum :decision, {
    pending: 0,
    penalty_applied: 1,
    rejected: 2,
    no_action: 3
  }, prefix: :decision

  # ═══════════════════════════════════════════════════════════════════
  # VALIDATIONS
  # ═══════════════════════════════════════════════════════════════════
  validates :race, presence: true
  validates :status, presence: true
  validates :decision, presence: true
  validate :decision_change_requires_official

  # ═══════════════════════════════════════════════════════════════════
  # SCOPES
  # ═══════════════════════════════════════════════════════════════════
  scope :ordered, -> { order(created_at: :desc) }
  scope :unofficial, -> { where(status: :unofficial) }
  scope :official, -> { where(status: :official) }
  scope :pending_decision, -> { official.decision_pending }
  scope :decided, -> { official.where.not(decision: :pending) }
  scope :with_reports, -> { includes(:reports) }

  # ═══════════════════════════════════════════════════════════════════
  # INSTANCE METHODS
  # ═══════════════════════════════════════════════════════════════════

  def single_report?
    reports_count == 1
  end

  def multiple_reports?
    reports_count > 1
  end

  # For UI: show "Report" for 1-report incidents, "Incident" for merged
  def display_type
    single_report? ? "Report" : "Incident"
  end

  def can_officialize?
    unofficial? && reports.any?
  end

  def can_decide?
    official? && decision_pending?
  end

  def officialize!(by_user:)
    return false unless can_officialize?

    update!(
      status: :official,
      officialized_at: Time.current,
      officialized_by: by_user.id
    )
  end

  def apply_penalty!(by_user:)
    return false unless can_decide?

    update!(
      decision: :penalty_applied,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  def reject!(by_user:)
    return false unless can_decide?

    update!(
      decision: :rejected,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  def mark_no_action!(by_user:)
    return false unless can_decide?

    update!(
      decision: :no_action,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  # ═══════════════════════════════════════════════════════════════════
  # CALLBACKS
  # ═══════════════════════════════════════════════════════════════════
  after_update_commit :broadcast_updated

  private

  def decision_change_requires_official
    return unless decision_changed? && !decision_pending?

    unless official?
      errors.add(:decision, "can only be set when incident is official")
    end
  end

  def broadcast_updated
    Incidents::BroadcastJob.perform_later(id)
  end
end
```

### **10. Report**

Reports are **observations only** - they have NO status. All status/decision logic lives on the Incident.

```ruby
# == Schema Information
#
# Table name: reports
#
# id               :bigint           not null, primary key
# race_id          :bigint           not null, index
# incident_id      :bigint           not null, index (always belongs to incident)
# user_id          :bigint           not null, index (reporter)
# race_location_id      :bigint           optional, index
# race_participation_id :bigint           optional, index (for bib/entry lookup)
# athlete_id            :bigint           optional, index (specific athlete, for team races)
# bib_number            :integer          not null, index
# description      :text             optional
# video_clip       :jsonb            optional {start_time, end_time}
# created_at       :datetime         not null, index
# updated_at       :datetime         not null
#
# NOTE: Reports have NO STATUS - they are observations only.
# Status and decisions live on the Incident model.
#
class Report < ApplicationRecord
  # ═══════════════════════════════════════════════════════════════════
  # ASSOCIATIONS
  # ═══════════════════════════════════════════════════════════════════
  belongs_to :race
  belongs_to :incident, counter_cache: true
  belongs_to :user
  belongs_to :race_location, optional: true
  belongs_to :race_participation, optional: true  # For bib/entry lookup
  belongs_to :athlete, optional: true              # Specific athlete (for team races: 12.1 vs 12.2)

  has_one_attached :video

  # ═══════════════════════════════════════════════════════════════════
  # HELPER METHODS
  # ═══════════════════════════════════════════════════════════════════
  
  # Get athlete name for display (handles both individual and team races)
  def athlete_name
    if athlete.present?
      athlete.display_name
    elsif race_participation&.team.present?
      race_participation.team.display_name
    elsif race_participation&.athlete.present?
      race_participation.athlete.display_name
    else
      "Bib #{bib_number}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # VALIDATIONS (minimal for speed - target < 100ms creation)
  # ═══════════════════════════════════════════════════════════════════
  validates :race_id, presence: true
  validates :incident_id, presence: true
  validates :user_id, presence: true
  validates :bib_number, presence: true,
                         numericality: { only_integer: true, greater_than: 0 }
  validate :validate_video_clip

  # ═══════════════════════════════════════════════════════════════════
  # NO STATUS ON REPORT
  # Reports are observations, not decisions.
  # All status logic lives on Incident.
  # ═══════════════════════════════════════════════════════════════════

  # ═══════════════════════════════════════════════════════════════════
  # SCOPES
  # ═══════════════════════════════════════════════════════════════════
  scope :ordered, -> { order(created_at: :desc) }
  scope :by_bib, ->(bib) { where(bib_number: bib) }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { where("created_at > ?", 1.hour.ago) }

  # ═══════════════════════════════════════════════════════════════════
  # CALLBACKS (minimal - heavy work in background)
  # ═══════════════════════════════════════════════════════════════════
  after_create_commit :broadcast_created

  private

  def validate_video_clip
    return unless video_clip.present?

    start_time = video_clip["start_time"]
    end_time = video_clip["end_time"]

    return unless start_time.present? && end_time.present?

    if start_time >= end_time
      errors.add(:video_clip, "start_time must be before end_time")
    end

    if start_time.negative?
      errors.add(:video_clip, "start_time must be positive")
    end
  end

  def broadcast_created
    Reports::BroadcastJob.perform_later(id)
  end
end
```

### **11. Rule**

```ruby
# == Schema Information
#
# Table name: rules
#
# id          :bigint           not null, primary key
# number      :string           not null
# title       :string           not null
# description :text
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class Rule < ApplicationRecord
  has_many :reports, dependent: :restrict_with_error

  validates :number, presence: true, uniqueness: true
  validates :title, presence: true

  # Scopes
  scope :ordered, -> { order(:number) }
end
```

---

## **Service Objects with dry-monads**

Business logic is encapsulated in service objects using dry-monads for explicit success/failure handling. All services live in `app/services/` organized by domain.

### **Competitions::CreateFromTemplate**

```ruby
# app/services/competitions/create_from_template.rb
module Competitions
  class CreateFromTemplate
    include Dry::Monads[:result, :do]

    def call(template:, attributes:, race_type_ids: nil)
      template       = yield find_template(template)
      race_types     = yield resolve_race_types(template, race_type_ids)
      validated_attrs = yield validate_attributes(attributes)
      competition    = yield create_competition(template, validated_attrs, race_types)

      Success(competition)
    end

    private

    def find_template(template)
      case template
      when CompetitionTemplate
        Success(template)
      when Integer, String
        found = CompetitionTemplate.find_by(id: template)
        found ? Success(found) : Failure([:not_found, "Template not found"])
      else
        Failure([:invalid_template, "Invalid template type"])
      end
    end

    def resolve_race_types(template, race_type_ids)
      if race_type_ids.present?
        types = template.race_types.where(id: race_type_ids)
        if types.empty?
          Failure([:no_race_types, "None of the specified race types belong to this template"])
        else
          Success(types)
        end
      else
        Success(template.race_types)
      end
    end

    def validate_attributes(attributes)
      required = %i[name place country start_date end_date]
      missing = required.select { |key| attributes[key].blank? }
      
      if missing.any?
        Failure([:validation_failed, { missing_fields: missing }])
      else
        Success(attributes)
      end
    end

    def create_competition(template, attributes, race_types)
      competition = nil
      
      ActiveRecord::Base.transaction do
        competition = Competition.create!(attributes)

        template.stage_templates.ordered.each do |stage_template|
          stage = competition.stages.create!(
            name: stage_template.name,
            description: stage_template.description,
            position: stage_template.position
          )

          stage_template.race_templates.ordered.each do |race_template|
            next unless race_types.include?(race_template.race_type)

            stage.races.create!(
              name: race_template.name,
              race_type: race_template.race_type,
              position: race_template.position
            )
          end
        end
      end
      
      Success(competition)
    rescue ActiveRecord::RecordInvalid => e
      Failure([:record_invalid, e.message])
    rescue ActiveRecord::RecordNotUnique => e
      Failure([:duplicate_record, e.message])
    end
  end
end
```

### **Competitions::Duplicate**

```ruby
# app/services/competitions/duplicate.rb
module Competitions
  class Duplicate
    include Dry::Monads[:result, :do]

    def call(competition:, new_attributes:, race_type_ids: nil, include_locations: false)
      source      = yield find_competition(competition)
      validated   = yield validate_new_attributes(new_attributes)
      race_types  = yield resolve_race_types(race_type_ids)
      new_comp    = yield duplicate_competition(source, validated, race_types, include_locations)

      Success(new_comp)
    end

    private

    def find_competition(competition)
      case competition
      when Competition
        Success(competition)
      when Integer, String
        found = Competition.find_by(id: competition)
        found ? Success(found) : Failure([:not_found, "Competition not found"])
      else
        Failure([:invalid_competition, "Invalid competition type"])
      end
    end

    def validate_new_attributes(attributes)
      if attributes[:name].blank?
        Failure([:validation_failed, { name: ["can't be blank"] }])
      else
        Success(attributes)
      end
    end

    def resolve_race_types(race_type_ids)
      if race_type_ids.present?
        Success(RaceType.where(id: race_type_ids))
      else
        Success(nil) # nil means include all
      end
    end

    def duplicate_competition(source, new_attributes, race_types, include_locations)
      new_competition = nil
      
      ActiveRecord::Base.transaction do
        new_competition = Competition.create!(
          source.attributes
                .except("id", "created_at", "updated_at")
                .merge(new_attributes.stringify_keys)
        )

        source.stages.ordered.each do |stage|
          new_stage = new_competition.stages.create!(
            name: stage.name,
            description: stage.description,
            date: stage.date,
            position: stage.position
          )

          stage.races.ordered.each do |race|
            next if race_types.present? && !race_types.include?(race.race_type)

            new_race = new_stage.races.create!(
              name: race.name,
              race_type: race.race_type,
              scheduled_at: race.scheduled_at,
              position: race.position
            )

            if include_locations
              race.race_locations.custom.ordered.each do |location|
                new_race.race_locations.create!(
                  name: location.name,
                  location_type: location.location_type,
                  has_camera: location.has_camera,
                  from_template: false,
                  position: location.position
                )
              end
            end
          end
        end
      end

      Success(new_competition)
    rescue ActiveRecord::RecordInvalid => e
      Failure([:record_invalid, e.message])
    end
  end
end
```

### **Incidents::Create**

```ruby
# app/services/incidents/create.rb
module Incidents
  class Create
    include Dry::Monads[:result, :do]

    def call(user:, params:)
      _           = yield authorize!(user)
      validated   = yield validate!(params)
      race        = yield find_race!(validated[:race_id])
      location    = yield find_location(validated[:race_location_id])
      incident    = yield persist!(race: race, location: location, params: validated)

      Success(incident)
    end

    private

    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized to create incidents"]) unless can_create?(user)
      Success(user)
    end

    def can_create?(user)
      user.referee? || user.var_operator? || user.admin?
    end

    def validate!(params)
      errors = {}
      errors[:race_id] = ["can't be blank"] if params[:race_id].blank?
      
      if errors.any?
        Failure([:validation_failed, errors])
      else
        Success(params.to_h.symbolize_keys)
      end
    end

    def find_race!(race_id)
      race = Race.find_by(id: race_id)
      race ? Success(race) : Failure([:not_found, "Race not found"])
    end

    def find_location(race_location_id)
      return Success(nil) if race_location_id.blank?
      
      location = RaceLocation.find_by(id: race_location_id)
      location ? Success(location) : Failure([:not_found, "Race location not found"])
    end

    def persist!(race:, location:, params:)
      incident = Incident.new(
        race: race,
        race_location: location,
        description: params[:description],
        status: :unofficial
      )

      if incident.save
        Success(incident)
      else
        Failure([:save_failed, incident.errors.to_h])
      end
    end
  end
end
```

### **Incidents::Officialize**

```ruby
# app/services/incidents/officialize.rb
module Incidents
  class Officialize
    include Dry::Monads[:result, :do]

    def call(user:, incident_id:)
      _        = yield authorize!(user)
      incident = yield find_incident!(incident_id)
      _        = yield validate_can_officialize!(incident)
      result   = yield officialize!(incident)

      Success(result)
    end

    private

    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Only jury president can officialize incidents"]) unless user.jury_president?
      Success(user)
    end

    def find_incident!(incident_id)
      incident = Incident.find_by(id: incident_id)
      incident ? Success(incident) : Failure([:not_found, "Incident not found"])
    end

    def validate_can_officialize!(incident)
      if incident.official?
        Failure([:already_official, "Incident is already official"])
      else
        Success(incident)
      end
    end

    def officialize!(incident)
      if incident.update(status: :official)
        Success(incident)
      else
        Failure([:update_failed, incident.errors.to_h])
      end
    end
  end
end
```

### **Reports::Create**

```ruby
# app/services/reports/create.rb
module Reports
  class Create
    include Dry::Monads[:result, :do]

    def call(user:, params:)
      _         = yield authorize!(user)
      validated = yield validate!(params)
      race      = yield find_race!(validated[:race_id])
      rule      = yield find_rule!(validated[:rule_id])
      location  = yield find_location(validated[:race_location_id])
      report    = yield persist!(user: user, race: race, rule: rule, location: location, params: validated)

      Success(report)
    end

    private

    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized to create reports"]) unless can_create?(user)
      Success(user)
    end

    def can_create?(user)
      user.referee? || user.var_operator?
    end

    def validate!(params)
      errors = {}
      errors[:race_id] = ["can't be blank"] if params[:race_id].blank?
      errors[:rule_id] = ["can't be blank"] if params[:rule_id].blank?
      
      if errors.any?
        Failure([:validation_failed, errors])
      else
        Success(params.to_h.symbolize_keys)
      end
    end

    def find_race!(race_id)
      race = Race.find_by(id: race_id)
      race ? Success(race) : Failure([:not_found, "Race not found"])
    end

    def find_rule!(rule_id)
      rule = Rule.find_by(id: rule_id)
      rule ? Success(rule) : Failure([:not_found, "Rule not found"])
    end

    def find_location(race_location_id)
      return Success(nil) if race_location_id.blank?
      
      location = RaceLocation.find_by(id: race_location_id)
      location ? Success(location) : Failure([:not_found, "Race location not found"])
    end

    def persist!(user:, race:, rule:, location:, params:)
      report = Report.new(
        user: user,
        race: race,
        rule: rule,
        race_location: location,
        description: params[:description],
        penalty: params[:penalty],
        video_start_time: params[:video_start_time],
        video_end_time: params[:video_end_time],
        status: :draft
      )

      if report.save
        Success(report)
      else
        Failure([:save_failed, report.errors.to_h])
      end
    end
  end
end
```

### **Reports::AttachToIncident**

```ruby
# app/services/reports/attach_to_incident.rb
module Reports
  class AttachToIncident
    include Dry::Monads[:result, :do]

    def call(user:, report_ids:, incident_id: nil, new_incident_params: nil)
      _        = yield authorize!(user)
      reports  = yield find_reports!(report_ids)
      incident = yield resolve_incident!(incident_id, new_incident_params, reports.first.race)
      _        = yield attach_reports!(reports, incident)

      Success(incident)
    end

    private

    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized"]) unless user.admin? || user.referee?
      Success(user)
    end

    def find_reports!(report_ids)
      reports = Report.where(id: report_ids)
      
      if reports.empty?
        Failure([:not_found, "No reports found"])
      elsif reports.map(&:race_id).uniq.size > 1
        Failure([:invalid_reports, "All reports must belong to the same race"])
      else
        Success(reports)
      end
    end

    def resolve_incident!(incident_id, new_incident_params, race)
      if incident_id.present?
        incident = Incident.find_by(id: incident_id)
        incident ? Success(incident) : Failure([:not_found, "Incident not found"])
      elsif new_incident_params.present?
        incident = Incident.new(
          race: race,
          description: new_incident_params[:description],
          status: :unofficial
        )
        incident.save ? Success(incident) : Failure([:save_failed, incident.errors.to_h])
      else
        Failure([:missing_incident, "Must provide incident_id or new_incident_params"])
      end
    end

    def attach_reports!(reports, incident)
      reports.update_all(incident_id: incident.id)
      Success(reports)
    end
  end
end
```

---

## **Authorization with Pundit**

Authorization is handled via [Pundit](https://github.com/varvet/pundit) policies. Each model has a corresponding policy class that defines what actions each role can perform.

### **Setup**

```ruby
# Gemfile
gem "pundit"

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
```

### **Base Policy**

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def admin?
    user&.admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
```

### **IncidentPolicy**

```ruby
# app/policies/incident_policy.rb
class IncidentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user&.referee? || user&.var_operator? || admin?
  end

  def update?
    admin? || (user&.referee? && record.unofficial?)
  end

  def destroy?
    admin?
  end

  def officialize?
    user&.jury_president?
  end

  def apply?
    user&.jury_president?
  end

  def decline?
    user&.jury_president?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.jury_president? || user.referee_manager?
        scope.all
      elsif user.international_referee?
        scope.all
      elsif user.national_referee?
        scope.joins(race: { stage: :competition })
             .where(competitions: { country: user.country })
      elsif user.var_operator?
        scope.all
      else
        scope.none
      end
    end
  end
end
```

### **ReportPolicy**

```ruby
# app/policies/report_policy.rb
class ReportPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user&.referee? || user&.var_operator?
  end

  def update?
    return true if admin?
    return false unless record.draft? || record.submitted?
    
    record.user_id == user&.id
  end

  def destroy?
    return true if admin?
    record.user_id == user&.id && record.draft?
  end

  def submit?
    record.user_id == user&.id && record.draft?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.jury_president? || user.referee_manager?
        scope.all
      elsif user.referee? || user.var_operator?
        scope.all
      else
        scope.none
      end
    end
  end
end
```

### **RacePolicy**

```ruby
# app/policies/race_policy.rb
class RacePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def start?
    admin?
  end

  def complete?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
```

### **RaceLocationPolicy**

```ruby
# app/policies/race_location_policy.rb
class RaceLocationPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def show_camera_stream?
    return true if admin?
    return true if user&.var_operator?
    
    user&.referee? && record.referee?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin? && !record.from_template?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      if user.broadcast_viewer?
        scope.with_camera
      else
        scope.all
      end
    end
  end
end
```

### **CompetitionPolicy**

```ruby
# app/policies/competition_policy.rb
class CompetitionPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    user&.referee_manager?
  end

  def duplicate?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
```

### **RaceTypePolicy**

```ruby
# app/policies/race_type_policy.rb
class RaceTypePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    user&.referee_manager?
  end

  def manage_templates?
    admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
```

### **Usage in Controllers**

```ruby
# app/controllers/incidents_controller.rb
class IncidentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @incidents = policy_scope(Incident).ordered
  end

  def show
    @incident = Incident.find(params[:id])
    authorize @incident
  end

  def create
    result = Incidents::Create.new.call(
      user: current_user,
      params: incident_params
    )

    case result
    in Success(incident)
      redirect_to incident, notice: "Incident created."
    in Failure([:validation_failed, errors])
      @errors = errors
      render :new, status: :unprocessable_entity
    in Failure([:forbidden, message])
      redirect_to incidents_path, alert: message
    in Failure([_, message])
      redirect_to incidents_path, alert: message
    end
  end

  def officialize
    result = Incidents::Officialize.new.call(
      user: current_user,
      incident_id: params[:id]
    )

    case result
    in Success(incident)
      redirect_to incident, notice: "Incident officialized."
    in Failure([:forbidden, message])
      redirect_to incidents_path, alert: message
    in Failure([_, message])
      redirect_to incidents_path, alert: message
    end
  end

  private

  def incident_params
    params.require(:incident).permit(:race_id, :race_location_id, :description)
  end
end
```

### **Competitions Controller with Services**

```ruby
# app/controllers/competitions_controller.rb
class CompetitionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @competitions = policy_scope(Competition).ordered
  end

  def show
    @competition = Competition.find(params[:id])
    authorize @competition
  end

  def new
    @competition = Competition.new
    @templates = CompetitionTemplate.ordered
    authorize @competition
  end

  def create
    authorize Competition

    if params[:template_id].present?
      create_from_template
    else
      create_directly
    end
  end

  def duplicate
    @competition = Competition.find(params[:id])
    authorize @competition

    result = Competitions::Duplicate.new.call(
      competition: @competition,
      new_attributes: duplicate_params,
      race_type_ids: params[:race_type_ids],
      include_locations: params[:include_locations] == "true"
    )

    case result
    in Success(new_competition)
      redirect_to new_competition, notice: "Competition duplicated successfully."
    in Failure([:validation_failed, errors])
      @errors = errors
      render :duplicate_form, status: :unprocessable_entity
    in Failure([_, message])
      redirect_to @competition, alert: message
    end
  end

  private

  def create_from_template
    result = Competitions::CreateFromTemplate.new.call(
      template: params[:template_id],
      attributes: competition_params,
      race_type_ids: params[:race_type_ids]
    )

    case result
    in Success(competition)
      redirect_to competition, notice: "Competition created from template."
    in Failure([:validation_failed, errors])
      @errors = errors
      @templates = CompetitionTemplate.ordered
      render :new, status: :unprocessable_entity
    in Failure([_, message])
      redirect_to competitions_path, alert: message
    end
  end

  def create_directly
    @competition = Competition.new(competition_params)

    if @competition.save
      redirect_to @competition, notice: "Competition created."
    else
      @templates = CompetitionTemplate.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def competition_params
    params.require(:competition).permit(:name, :place, :country, :description, :start_date, :end_date, :webpage_url)
  end

  def duplicate_params
    params.require(:competition).permit(:name, :place, :country, :start_date, :end_date)
  end
end
```

---

## **Role Permission Matrix**

| Action | Jury President | Referee Manager | Int'l Referee | Nat'l Referee | VAR Operator | Broadcast Viewer |
|--------|----------------|-----------------|---------------|---------------|--------------|------------------|
| **Incidents** |
| View all | ✅ | ✅ | ✅ | Own country | ✅ | ❌ |
| Create | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Update | ✅ | ✅ | Unofficial only | Unofficial only | ❌ | ❌ |
| Officialize | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Apply/Decline | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Delete | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Reports** |
| View all | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Create | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Update own | ✅ | ✅ | Draft/Submitted | Draft/Submitted | Draft/Submitted | ❌ |
| Delete | ✅ | ✅ | Own draft | Own draft | Own draft | ❌ |
| **Competitions** |
| View | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Update | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duplicate | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Delete | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Races** |
| View | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Camera Streams** |
| View all | ✅ | ✅ | ❌ | ❌ | ✅ | Camera locations only |
| View referee locations | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

---

## **Quick Summary of Each Model**

### **1. User**
Represents a system user with attributes like name, email, and role (enum). Uses Rails 8.1 authentication with `has_secure_password` for password-based login and magic links for passwordless authentication. Role-based authorization is handled via Pundit policies.

### **1a. Session**
Manages user authentication sessions with secure tokens. Each session tracks the user's IP address and user agent for security auditing. Tokens are guaranteed unique via retry loop.

### **1b. MagicLink**
Enables passwordless authentication via email. Magic links are single-use, time-limited tokens (15 minutes) that allow users to log in without entering a password. Old valid links are invalidated when new ones are created.

### **2. CompetitionTemplate**
Reusable template for creating competitions. Defines the structure (stages, races) and which race types are available. Use `Competitions::CreateFromTemplate` service to instantiate a new competition.

### **2a. StageTemplate**
Defines a stage within a CompetitionTemplate. Has a name, description, and position with uniqueness constraint.

### **2b. RaceTemplate**
Defines a race within a StageTemplate. Links to a RaceType to determine which location templates to use.

### **2c. CompetitionTemplateRaceType**
Join table linking CompetitionTemplate to RaceType. Defines which race types are available when creating a competition from this template.

### **3. Competition**
Represents a specific competition event (e.g., "Verbier Sprint Weekend 2024") with place, dates, description, logo, and webpage URL. Can be created from a template or duplicated from an existing competition using service objects.

### **4. Stage**
Represents a stage within a Competition (e.g., "Qualification", "Semi-Finals", "Finals"). Each stage includes multiple races and has a position for ordering with uniqueness constraint.

### **5. RaceType**
Defines the general type of a race (e.g., sprint, vertical, individual, relay). Contains location templates that define the default locations for races of this type.

### **6. RaceTypeLocationTemplate**
Defines default locations for a RaceType. When a new Race is created, these templates are automatically copied to create the race's actual locations.

### **7. Race**
Represents a specific race within a stage, linked to a race type. When created, automatically copies locations from the RaceType's templates. Has a status (scheduled, in_progress, completed, cancelled).

### **8. RaceLocation**
Represents an actual location within a specific race. Created automatically from templates when a race is created (`from_template: true`), plus custom locations can be added (`from_template: false`). Tracks camera availability and stream URLs.

### **9. Incident**
Handles grouped violations or race-related issues that may involve multiple reports. Has status (unofficial/official) and official_status (pending/applied/declined).

### **10. Report**
Tracks individual referee-reported incidents during a race. Includes details like rule violations, videos, and penalties. Includes `user_id` to track the reporter and status workflow (draft/submitted/reviewed).

### **11. Rule**
Defines the rules of the competition, which are referenced in reports to clarify the violated rule.

---

## **Business Logic Examples**

### Creating Competition from Template

```ruby
# Using the service
result = Competitions::CreateFromTemplate.new.call(
  template: CompetitionTemplate.find_by!(name: "Standard ISMF Event"),
  attributes: {
    name: "Verbier Sprint Weekend 2025",
    place: "Verbier",
    country: "CH",
    start_date: Date.new(2025, 2, 15),
    end_date: Date.new(2025, 2, 16)
  },
  race_type_ids: [sprint.id, vertical.id]
)

case result
in Success(competition)
  puts "Created: #{competition.name}"
in Failure([:not_found, message])
  puts "Template not found: #{message}"
in Failure([:validation_failed, errors])
  puts "Validation errors: #{errors}"
in Failure([code, message])
  puts "Error (#{code}): #{message}"
end
```

### Duplicating an Existing Competition

```ruby
# Duplicate with all race types
result = Competitions::Duplicate.new.call(
  competition: existing_competition,
  new_attributes: {
    name: "Verbier Sprint Weekend 2026",
    start_date: Date.new(2026, 2, 14),
    end_date: Date.new(2026, 2, 15)
  }
)

# Duplicate with only specific race types and custom locations
individual = RaceType.find_by!(name: "individual")
result = Competitions::Duplicate.new.call(
  competition: existing_competition,
  new_attributes: { name: "Individual Championship 2026" },
  race_type_ids: [individual.id],
  include_locations: true
)
```

### Creating an Incident

```ruby
result = Incidents::Create.new.call(
  user: current_user,
  params: {
    race_id: race.id,
    race_location_id: location.id,
    description: "Athlete cut the course at checkpoint 2"
  }
)

case result
in Success(incident)
  puts "Incident #{incident.id} created"
in Failure([:unauthorized, _])
  puts "Please log in"
in Failure([:forbidden, message])
  puts "Not allowed: #{message}"
in Failure([:validation_failed, errors])
  puts "Invalid: #{errors}"
end
```

### Attaching Reports to an Incident

```ruby
# Combine existing reports into a new incident
result = Reports::AttachToIncident.new.call(
  user: current_user,
  report_ids: [report1.id, report2.id],
  new_incident_params: { description: "Multiple violations at start line" }
)

# Or attach to existing incident
result = Reports::AttachToIncident.new.call(
  user: current_user,
  report_ids: [report3.id],
  incident_id: existing_incident.id
)
```

### Authorizing Actions with Pundit

```ruby
# In controller
def show
  @incident = Incident.find(params[:id])
  authorize @incident
end

# In view
<% if policy(@incident).officialize? %>
  <%= button_to "Officialize", officialize_incident_path(@incident) %>
<% end %>
```

### Scoping Records by Authorization

```ruby
# Only returns incidents the user is authorized to see
@incidents = policy_scope(Incident).ordered
```

---

## **Database Indexes**

Ensure these indexes exist for optimal query performance:

```ruby
# db/migrate/xxx_add_indexes.rb
class AddIndexes < ActiveRecord::Migration[7.1]
  def change
    # Users
    add_index :users, :email, unique: true
    add_index :users, :role

    # Sessions
    add_index :sessions, :token, unique: true
    add_index :sessions, :user_id

    # Magic Links
    add_index :magic_links, :token, unique: true
    add_index :magic_links, :user_id
    add_index :magic_links, [:user_id, :expires_at, :used_at]

    # Templates
    add_index :stage_templates, [:competition_template_id, :position], unique: true
    add_index :race_templates, [:stage_template_id, :position], unique: true
    add_index :competition_template_race_types, [:competition_template_id, :race_type_id], unique: true, name: 'idx_comp_template_race_types_unique'

    # Competitions
    add_index :stages, [:competition_id, :position], unique: true
    add_index :races, [:stage_id, :position], unique: true
    add_index :races, :race_type_id
    add_index :races, :status

    # Race Types
    add_index :race_types, :name, unique: true
    add_index :race_type_location_templates, [:race_type_id, :position], unique: true
    add_index :race_type_location_templates, [:race_type_id, :name], unique: true

    # Locations
    add_index :race_locations, [:race_id, :name], unique: true
    add_index :race_locations, [:race_id, :position]
    add_index :race_locations, :has_camera

    # Incidents & Reports
    add_index :incidents, :race_id
    add_index :incidents, :status
    add_index :reports, :race_id
    add_index :reports, :incident_id
    add_index :reports, :user_id
    add_index :reports, :rule_id

    # Rules
    add_index :rules, :number, unique: true
  end
end
```

---

## **Testing Services**

```ruby
# spec/services/competitions/create_from_template_spec.rb
require 'rails_helper'

RSpec.describe Competitions::CreateFromTemplate do
  subject(:service) { described_class.new }

  let(:template) { create(:competition_template, :with_stages_and_races) }
  let(:sprint) { create(:race_type, name: "sprint") }
  let(:valid_attributes) do
    {
      name: "Test Competition 2025",
      place: "Test City",
      country: "CH",
      start_date: Date.tomorrow,
      end_date: Date.tomorrow + 2.days
    }
  end

  describe '#call' do
    context 'with valid parameters' do
      it 'returns Success with competition' do
        result = service.call(
          template: template,
          attributes: valid_attributes
        )

        expect(result).to be_success
        expect(result.success).to be_a(Competition)
        expect(result.success.name).to eq("Test Competition 2025")
      end

      it 'creates stages from template' do
        result = service.call(template: template, attributes: valid_attributes)

        expect(result.success.stages.count).to eq(template.stage_templates.count)
      end
    end

    context 'with missing required attributes' do
      let(:invalid_attributes) { { name: "Test" } }

      it 'returns Failure with validation errors' do
        result = service.call(
          template: template,
          attributes: invalid_attributes
        )

        expect(result).to be_failure
        
        case result
        in Failure([:validation_failed, errors])
          expect(errors[:missing_fields]).to include(:place, :country)
        else
          fail "Expected validation_failed"
        end
      end
    end

    context 'with non-existent template' do
      it 'returns Failure with not_found' do
        result = service.call(
          template: 99999,
          attributes: valid_attributes
        )

        expect(result).to be_failure
        
        case result
        in Failure([:not_found, message])
          expect(message).to include("Template")
        else
          fail "Expected not_found"
        end
      end
    end
  end
end
```
