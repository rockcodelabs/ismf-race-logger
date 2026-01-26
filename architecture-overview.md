# Architecture Overview

This document provides a detailed overview of the architecture and models for the race system, integrating users, roles, competitions, races, locations, incidents, reports, and authorization via Pundit.

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
# role_id         :bigint           not null, foreign_key
# country         :string
# ref_level       :enum             roles: [:national, :international]
# created_at      :datetime         not null
# updated_at      :datetime         not null
#
class User < ApplicationRecord
  # Rails 8.1 Authentication
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy

  belongs_to :role

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Normalizations (Rails 7.1+)
  normalizes :email, with: ->(email) { email.strip.downcase }

  # Scopes
  scope :referees, -> { joins(:role).where(roles: { name: %w[national_referee international_referee] }) }
  scope :var_operators, -> { joins(:role).where(roles: { name: 'var_operator' }) }

  # Role check methods
  def var_operator?
    role.name == "var_operator"
  end

  def referee?
    %w[national_referee international_referee].include?(role.name)
  end

  def national_referee?
    role.name == "national_referee"
  end

  def international_referee?
    role.name == "international_referee"
  end

  def jury_president?
    role.name == "jury_president"
  end

  def referee_manager?
    role.name == "referee_manager"
  end

  def broadcast_viewer?
    role.name == "broadcast_viewer"
  end

  # Generate magic link token for passwordless login
  def generate_magic_link!
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

  before_create :generate_token

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
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

### **2. Role**

```ruby
# == Schema Information
#
# Table name: roles
#
# id          :bigint           not null, primary key
# name        :string           not null, unique
# description :text
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class Role < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  # Enumerations
  enum :name, {
    national_referee: "national_referee",
    international_referee: "international_referee",
    var_operator: "var_operator",
    jury_president: "jury_president",
    referee_manager: "referee_manager",
    broadcast_viewer: "broadcast_viewer"
  }

  validates :name, presence: true, uniqueness: true
end
```

### **3. CompetitionTemplate**

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
  has_many :stage_templates, -> { order(:position) }, dependent: :destroy
  has_many :competition_template_race_types, dependent: :destroy
  has_many :race_types, through: :competition_template_race_types

  validates :name, presence: true, uniqueness: true

  # Create a new competition from this template
  def create_competition!(attributes = {})
    Competition.transaction do
      competition = Competition.create!(attributes)

      stage_templates.each do |stage_template|
        stage = competition.stages.create!(
          name: stage_template.name,
          description: stage_template.description,
          position: stage_template.position
        )

        stage_template.race_templates.each do |race_template|
          next unless race_types.include?(race_template.race_type)

          stage.races.create!(
            name: race_template.name,
            race_type: race_template.race_type,
            position: race_template.position
          )
        end
      end

      competition
    end
  end
end
```

### **3a. StageTemplate**

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
  has_many :race_templates, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

### **3b. RaceTemplate**

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
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

### **3c. CompetitionTemplateRaceType**

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

### **4. Competition**

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
  has_many :stages, -> { order(:position) }, dependent: :destroy
  has_many :races, through: :stages

  has_one_attached :logo

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position) }
  validates :place, presence: true
  validates :country, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  scope :upcoming, -> { where("start_date > ?", Date.current).order(:start_date) }
  scope :ongoing, -> { where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  scope :past, -> { where("end_date < ?", Date.current).order(start_date: :desc) }

  # Duplicate this competition with new attributes
  # Options:
  #   - race_type_ids: Array of race type IDs to include (default: all)
  #   - include_locations: Copy custom locations (default: false, only template locations)
  def duplicate!(new_attributes = {}, race_type_ids: nil, include_locations: false)
    Competition.transaction do
      new_competition = Competition.create!(
        attributes.except("id", "created_at", "updated_at").merge(new_attributes)
      )

      stages.each do |stage|
        new_stage = new_competition.stages.create!(
          name: stage.name,
          description: stage.description,
          date: stage.date,
          position: stage.position
        )

        stage.races.each do |race|
          next if race_type_ids.present? && !race_type_ids.include?(race.race_type_id)

          new_race = new_stage.races.create!(
            name: race.name,
            race_type: race.race_type,
            scheduled_at: race.scheduled_at,
            position: race.position
          )

          # Copy custom locations if requested
          if include_locations
            race.race_locations.custom.each do |location|
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

      new_competition
    end
  end

  # Create competition from template with selected race types
  def self.create_from_template!(template, attributes, race_type_ids: nil)
    selected_race_types = if race_type_ids.present?
      template.race_types.where(id: race_type_ids)
    else
      template.race_types
    end

    Competition.transaction do
      competition = Competition.create!(attributes)

      template.stage_templates.each do |stage_template|
        stage = competition.stages.create!(
          name: stage_template.name,
          description: stage_template.description,
          position: stage_template.position
        )

        stage_template.race_templates.each do |race_template|
          next unless selected_race_types.include?(race_template.race_type)

          stage.races.create!(
            name: race_template.name,
            race_type: race_template.race_type,
            position: race_template.position
          )
        end
      end

      competition
    end
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be after start date") if end_date < start_date
  end
end
```

### **5. Stage**

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
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position) }

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

  validates :name, presence: true, uniqueness: true

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

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :name, uniqueness: { scope: :race_type_id }

  default_scope { order(:position) }
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

  after_create :copy_locations_from_template

  private

  # Automatically copy default locations from RaceType template
  def copy_locations_from_template
    race_type.location_templates.each do |template|
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
# id               :bigint           not null, primary key
# race_id          :bigint           not null, foreign_key
# name             :string           not null
# location_type    :enum             values: [:referee, :spectator, :var]
# has_camera       :boolean          default: false
# camera_stream_url :string
# from_template    :boolean          default: false, null: false
# position         :integer          not null, default: 0
# created_at       :datetime         not null
# updated_at       :datetime         not null
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

  validates :name, presence: true
  validates :name, uniqueness: { scope: :race_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :with_camera, -> { where(has_camera: true) }
  scope :from_template, -> { where(from_template: true) }
  scope :custom, -> { where(from_template: false) }

  default_scope { order(:position) }
end
```

### **10. Incident**

```ruby
# == Schema Information
#
# Table name: incidents
#
# id                :bigint           not null, primary key
# race_id           :bigint           foreign key
# race_location_id  :bigint           foreign key
# description       :text
# status            :enum             values: [:unofficial, :official]
# official_status   :enum             values: [:applied, :declined]
# unofficial_status :enum             values: [:reported, :under_verification]
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
class Incident < ApplicationRecord
  belongs_to :race
  belongs_to :race_location
  has_many :reports, dependent: :destroy

  # Scopes for filtering
  scope :official, -> { where(status: :official) }
  scope :unofficial, -> { where(status: :unofficial) }

  # Combine penalties and observers for display
  def combined_penalties
    reports.pluck(:penalty).join(', ')
  end
end
```

### **11. Report**

```ruby
# == Schema Information
#
# Table name: reports
#
# id                :bigint           not null, primary key
# race_id           :bigint           foreign key
# incident_id       :bigint           nullable (not all reports become incidents)
# rule_id           :bigint           foreign key
# user_id           :bigint           foreign key (reporter)
# race_location_id  :bigint           optional
# description       :text
# video_start_time  :integer          optional
# video_end_time    :integer          optional
# penalty           :string
# status            :enum             values: [:unofficial, :official]
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
class Report < ApplicationRecord
  belongs_to :race
  belongs_to :incident, optional: true # Only some reports form incidents
  belongs_to :rule
  belongs_to :user # The reporter
  belongs_to :race_location, optional: true

  has_one_attached :video

  validate :validate_video_times # Custom validations allow narrowing evidence

  # Time range validation
  def validate_video_times
    return unless video.attached? && (video_start_time.present? || video_end_time.present?)

    errors.add(:video_start_time, "must be earlier than the end time") if video_start_time >= video_end_time
  end
end
```

### **12. Rule**

```ruby
# == Schema Information
#
# Table name: rules
#
# id                :bigint           not null, primary key
# number            :string           not null
# title             :string           not null
# description       :text
# created_at        :datetime         not null
# updated_at        :datetime         not null
#
class Rule < ApplicationRecord
  has_many :reports
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

  # Jury president and referee manager have full access by default
  def admin?
    user.jury_president? || user.referee_manager?
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
    true # All authenticated users can view incidents list
  end

  def show?
    true # All authenticated users can view incident details
  end

  def create?
    user.referee? || user.var_operator? || admin?
  end

  def update?
    admin? || (user.referee? && record.status == "unofficial")
  end

  def destroy?
    admin?
  end

  def officialize?
    user.jury_president?
  end

  def apply?
    user.jury_president?
  end

  def decline?
    user.jury_president?
  end

  class Scope < Scope
    def resolve
      if user.jury_president? || user.referee_manager?
        scope.all
      elsif user.international_referee?
        scope.all # International referees see all incidents
      elsif user.national_referee?
        # National referees see incidents from their country's races
        scope.joins(race: { stage: :world_cup_edition })
             .where(races: { country: user.country })
      elsif user.var_operator?
        scope.all # VAR operators need to see all for video review
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
    user.referee? || user.var_operator?
  end

  def update?
    return true if admin?
    return false unless record.status == "unofficial"

    record.user_id == user.id # Only the reporter can edit their own unofficial report
  end

  def destroy?
    admin? || (record.user_id == user.id && record.status == "unofficial")
  end

  def officialize?
    user.jury_president?
  end

  class Scope < Scope
    def resolve
      if user.jury_president? || user.referee_manager?
        scope.all
      elsif user.referee? || user.var_operator?
        scope.all # Referees and VAR operators can see all reports
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

  class Scope < Scope
    def resolve
      scope.all # All authenticated users can see races
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
    return true if user.var_operator?

    # Referees can only see cameras at their assigned locations
    user.referee? && record.location_type == "referee"
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

  class Scope < Scope
    def resolve
      if user.broadcast_viewer?
        scope.with_camera # Broadcast viewers only see locations with cameras
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
    user.referee_manager? # Only referee manager can delete competitions
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
    user.referee_manager? # Only referee manager can delete race types
  end

  def manage_templates?
    admin? # Add/remove/edit location templates
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
  def index
    @incidents = policy_scope(Incident)
  end

  def show
    @incident = Incident.find(params[:id])
    authorize @incident
  end

  def create
    @incident = Incident.new(incident_params)
    authorize @incident

    if @incident.save
      redirect_to @incident, notice: "Incident created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def officialize
    @incident = Incident.find(params[:id])
    authorize @incident

    @incident.update!(status: :official)
    redirect_to @incident, notice: "Incident officialized."
  end

  private

  def incident_params
    params.require(:incident).permit(:race_id, :race_location_id, :description)
  end
end
```

### **Role Permission Matrix**

| Action | Jury President | Referee Manager | Int'l Referee | Nat'l Referee | VAR Operator | Broadcast Viewer |
|--------|---------------|-----------------|---------------|---------------|--------------|------------------|
| **Incidents** |
| View all | ✅ | ✅ | ✅ | Own country | ✅ | ❌ |
| Create | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Update | ✅ | ✅ | Unofficial only | Unofficial only | ❌ | ❌ |
| Officialize | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Delete | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Reports** |
| View all | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Create | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Update own | ✅ | ✅ | Unofficial only | Unofficial only | Unofficial only | ❌ |
| Delete | ✅ | ✅ | Own unofficial | Own unofficial | Own unofficial | ❌ |
| **Races** |
| View | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Camera Streams** |
| View | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ (camera locations only) |

---

## **Quick Summary of Each Model**

### **1. User**
Represents a system user with attributes like name, email, and associated role. Uses Rails 8.1 authentication with `has_secure_password` for password-based login and magic links for passwordless authentication. Role-based authorization is handled via Pundit policies.

### **1a. Session**
Manages user authentication sessions with secure tokens. Each session tracks the user's IP address and user agent for security auditing.

### **1b. MagicLink**
Enables passwordless authentication via email. Magic links are single-use, time-limited tokens (15 minutes) that allow users to log in without entering a password.

### **2. Role**
Defines user roles (e.g., national referee, jury president). It is associated with users and determines their authorization level via Pundit policies.

### **3. CompetitionTemplate**
Reusable template for creating competitions. Defines the structure (stages, races) and which race types are available. Use `create_competition!` to instantiate a new competition from this template.

### **3a. StageTemplate**
Defines a stage within a CompetitionTemplate. Has a name, description, and position.

### **3b. RaceTemplate**
Defines a race within a StageTemplate. Links to a RaceType to determine which location templates to use.

### **3c. CompetitionTemplateRaceType**
Join table linking CompetitionTemplate to RaceType. Defines which race types are available when creating a competition from this template.

### **4. Competition**
Represents a specific competition event (e.g., "Verbier Sprint Weekend 2024") with place, dates, description, logo, and webpage URL. Can be created from a template or duplicated from an existing competition with `duplicate!` method. Supports filtering by race types when duplicating.

### **5. Stage**
Represents a stage within a Competition (e.g., "Qualification", "Semi-Finals", "Finals"). Each stage includes multiple races and has a position for ordering.

### **6. RaceType**
Defines the general type of a race (e.g., sprint, vertical, individual, relay). Contains location templates that define the default locations for races of this type.

### **7. RaceTypeLocationTemplate**
Defines default locations for a RaceType. When a new Race is created, these templates are automatically copied to create the race's actual locations. Examples: sprint type has start, finish, top, walk, platform_1, platform_2.

### **8. Race**
Represents a specific race within a stage, linked to a race type. When created, automatically copies locations from the RaceType's templates. Has a status (scheduled, in_progress, completed, cancelled).

### **9. RaceLocation**
Represents an actual location within a specific race. Created automatically from templates when a race is created (`from_template: true`), plus custom locations can be added (`from_template: false`). Tracks camera availability and stream URLs.

### **10. Incident**
Handles grouped violations or race-related issues that may involve multiple reports and statuses (e.g., unofficial and official statuses).

### **11. Report**
Tracks individual referee-reported incidents during a race. Includes details like rule violations, videos, and penalties. Now includes `user_id` to track the reporter.

### **12. Rule**
Defines the rules of the competition, which are referenced in reports to clarify the violated rule.

---

## **Combined Business Logic**

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
@incidents = policy_scope(Incident)
```

### Aggregating Race Information
```ruby
race.all_locations.each do |location|
  puts location.name
end
```

### Incident Creation (From Multiple Reports)
```ruby
# Combine reports into one incident
incident = Incident.create!(race: race, description: "Multiple incidents reported")
report1.update!(incident: incident)
report2.update!(incident: incident)
```

### Creating Competition from Template
```ruby
# Find template and select race types
template = CompetitionTemplate.find_by!(name: "Standard ISMF Event")
sprint = RaceType.find_by!(name: "sprint")
vertical = RaceType.find_by!(name: "vertical")

# Create competition with only sprint and vertical races
competition = Competition.create_from_template!(
  template,
  {
    name: "Verbier Sprint Weekend 2025",
    place: "Verbier",
    country: "CH",
    start_date: Date.new(2025, 2, 15),
    end_date: Date.new(2025, 2, 16)
  },
  race_type_ids: [sprint.id, vertical.id]
)
```

### Duplicating an Existing Competition
```ruby
# Duplicate with all race types
new_competition = existing_competition.duplicate!(
  name: "Verbier Sprint Weekend 2026",
  start_date: Date.new(2026, 2, 14),
  end_date: Date.new(2026, 2, 15)
)

# Duplicate with only individual races
individual = RaceType.find_by!(name: "individual")
new_competition = existing_competition.duplicate!(
  { name: "Individual Championship 2026" },
  race_type_ids: [individual.id],
  include_locations: true  # Also copy custom locations
)
```
