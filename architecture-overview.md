# Architecture Overview

This document provides a detailed overview of the architecture and models for the race system, integrating users, roles, races, locations, incidents, reports, and permissions.

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

### **3. RaceType**

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

### **4. Race**

```ruby
# == Schema Information
#
# Table name: races
#
# id           :bigint           not null, primary key
# name         :string           not null
# race_type_id :bigint           not null, foreign_key
# created_at   :datetime         not null
# updated_at   :datetime         not null
#
class Race < ApplicationRecord
  belongs_to :race_type
  has_many :race_locations, dependent: :destroy
  has_many :incidents, dependent: :destroy

  # Aggregates default and specific locations for the race
  def all_locations
    race_type.race_locations.default + race_locations
  end
end
```

### **5. RaceLocation**

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

### **6. Incident**

```ruby
# == Schema Information
#
# Table name: incidents
#
# id                :bigint           not null, primary key
# race_id           :bigint           foreign_key
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

### **7. Report**

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

### **8. Rule**

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