# Architecture Overview

This document provides a detailed overview of the architecture and models for the race system, integrating users, roles, races, locations, incidents, reports, world cup editions, stages, and permissions.

---

## Recommended Models

### **1. User**

```ruby
# == Schema Information
#
# Table name: users
#
# id         :bigint           not null, primary key
# name       :string           not null
# email      :string           not null, unique
# role_id    :bigint           not null, foreign_key
# country    :string
# ref_level  :enum             roles: [:national, :international]
# created_at :datetime         not null
# updated_at :datetime         not null
#
class User < ApplicationRecord
  belongs_to :role

  # Scopes
  scope :referees, -> { joins(:role).where(roles: { name: %w[national_referee international_referee] }) }
  scope :var_operators, -> { joins(:role).where(roles: { name: 'var_operator' }) }

  # Methods
  def var_operator?
    role.name == "var_operator"
  end

  def referee?
    %w[national_referee international_referee].include?(role.name)
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
  has_many :users, dependent: :destroy

  # Enumerations
  enum name: { national_referee: "national_referee",
               international_referee: "international_referee",
               var_operator: "var_operator",
               jury_president: "jury_president",
               referee_manager: "referee_manager",
               broadcast_viewer: "broadcast_viewer" }
end
```

### **3. RolePermission**

```ruby
# == Schema Information
#
# Table name: role_permissions
#
# id          :bigint           not null, primary key
# role_id     :bigint           not null, foreign_key
# action      :string           not null
# resource    :string           not null
# created_at  :datetime         not null
# updated_at  :datetime         not null
#
class RolePermission < ApplicationRecord
  belongs_to :role

  validates :action, :resource, presence: true
end
```

### **4. AuditLog**

```ruby
# == Schema Information
#
# Table name: audit_logs
#
# id          :bigint           not null, primary key
# user_id     :bigint           optional, foreign_key
# action      :string           not null
# resource    :string           optional
# details     :jsonb
# created_at  :datetime         not null
#
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true
end
```

### **5. WorldCupEdition**

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

### **6. Stage**

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

### **7. Race**

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

### **8. RaceType**

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

### **9. RaceLocation**

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

## **Quick Summary of Each Model**

### **1. User**
Represents a system user with attributes like name, email, and associated role. It determines the user's responsibilities and permissions in the system (e.g., referee, VAR operator).

### **2. Role**
Defines user roles (e.g., national referee, jury president). It is associated with users and determines their functionality within the system.

### **3. RolePermission**
Specifies the actions and resources a role can access (e.g., viewing camera streams or creating incidents).

### **4. AuditLog**
Used to track system activities, such as creating a report, updating incidents, or accessing video streams, ensuring accountability.

### **5. WorldCupEdition**
Represents a particular World Cup Edition (e.g., World Cup 2024), which consists of multiple stages.

### **6. Stage**
Represents a stage within a World Cup Edition (e.g., Pre-Qualification, Semi-Finals). Each stage includes multiple races.

### **7. Race**
Represents a specific race within a stage, linked to a race type (e.g., sprint, relay). Each race can have locations, incidents, and reports.

### **8. RaceType**
Defines the general type of a race (e.g., sprint, vertical), along with the default locations.

### **9. RaceLocation**
Represents locations within a race where referees, spectators, and VAR operators are assigned. Some locations include cameras.

### **10. Incident**
Handles grouped violations or race-related issues that may involve multiple reports and statuses (e.g., unofficial and official statuses).

### **11. Report**
Tracks individual referee-reported incidents during a race. Includes details like rule violations, videos, and penalties.

### **12. Rule**
Defines the rules of the competition, which are referenced in reports to clarify the violated rule.

---

## **Combined Business Logic**

### General User Access Management
```ruby
class User
  def can?(action, resource)
    role.permissions.exists?(action: action, resource: resource)
  end
end
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
