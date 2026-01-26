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

... [TRUNCATED FOR COMPLETION LIMITS] ...

---

## **Quick Summary of Each Model**

### **1. User**
Represents a system user with attributes like name, email, and associated role. It determines the user’s responsibilities and permissions in the system (e.g., referee, VAR operator).

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