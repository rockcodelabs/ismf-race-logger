# Architecture Overview

This document provides a detailed overview of the architecture and models for the race system, integrating users, roles, races, locations, incidents, reports, world cup editions, stages, and authorization via Pundit.

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

### **3. WorldCupEdition**

```ruby
# == Schema Information
#
# Table name: world_cup_editions
#
# id          :bigint           not null, primary key
# name        :string           not null, unique
# year        :integer          not null
# description :text
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class WorldCupEdition < ApplicationRecord
  has_many :stages, dependent: :destroy

  # Example: World Cup 2026
  validates :name, presence: true, uniqueness: true
  validates :year, presence: true, numericality: { greater_than: 1900 }
end
```

### **4. Stage**

```ruby
# == Schema Information
#
# Table name: stages
#
# id                  :bigint           not null, primary key
# world_cup_edition_id :bigint           not null, foreign_key
# name                :string           not null
# description         :text
# created_at          :datetime         not null
# updated_at          :datetime         not null
#
class Stage < ApplicationRecord
  belongs_to :world_cup_edition
  has_many :races, dependent: :destroy

  validates :name, presence: true
end
```

### **5. Race**

```ruby
# == Schema Information
#
# Table name: races
#
# id           :bigint           not null, primary key
# name         :string           not null
# race_type_id :bigint           not null, foreign_key
# stage_id     :bigint           not null, foreign_key
# created_at   :datetime         not null
# updated_at   :datetime         not null
#
class Race < ApplicationRecord
  belongs_to :stage
  belongs_to :race_type
  has_many :race_locations, dependent: :destroy
  has_many :incidents, dependent: :destroy

  # Aggregates default and specific locations for the race
  def all_locations
    race_type.race_locations.default + race_locations
  end
end
```

### **6. RaceType**

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
  has_many :race_locations, dependent: :destroy
  has_many :races, dependent: :destroy
end
```

### **7. RaceLocation**

```ruby
# == Schema Information
#
# Table name: race_locations
#
# id               :bigint           not null, primary key
# race_type_id     :bigint           foreign key
# race_id          :bigint           foreign key
# name             :string           not null
# location_type    :enum             values: [:referee, :spectator, :var]
# has_camera       :boolean          default: false
# camera_stream_url :string
# default          :boolean          default: false, null: false
# created_at       :datetime         not null
# updated_at       :datetime         not null
#
class RaceLocation < ApplicationRecord
  belongs_to :race_type, optional: true
  belongs_to :race, optional: true
  has_many :reports

  # Filter scopes
  scope :with_camera, -> { where(has_camera: true) }
  scope :referee_areas, -> { where(location_type: :referee) }
end
```

### **8. Incident**

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

### **9. Report**

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

### **10. Rule**

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

### **WorldCupEditionPolicy**

```ruby
# app/policies/world_cup_edition_policy.rb
class WorldCupEditionPolicy < ApplicationPolicy
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
    user.referee_manager? # Only referee manager can delete editions
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

### **3. WorldCupEdition**
Represents a particular World Cup Edition (e.g., World Cup 2024), which consists of multiple stages.

### **4. Stage**
Represents a stage within a World Cup Edition (e.g., Pre-Qualification, Semi-Finals). Each stage includes multiple races.

### **5. Race**
Represents a specific race within a stage, linked to a race type (e.g., sprint, relay). Each race can have locations, incidents, and reports.

### **6. RaceType**
Defines the general type of a race (e.g., sprint, vertical), along with the default locations.

### **7. RaceLocation**
Represents locations within a race where referees, spectators, and VAR operators are assigned. Some locations include cameras.

### **8. Incident**
Handles grouped violations or race-related issues that may involve multiple reports and statuses (e.g., unofficial and official statuses).

### **9. Report**
Tracks individual referee-reported incidents during a race. Includes details like rule violations, videos, and penalties. Now includes `user_id` to track the reporter.

### **10. Rule**
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
