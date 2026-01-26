---
name: dry-monads-patterns
description: ISMF Race Logger mandatory pattern for service objects using dry-monads Result monad with Success/Failure and do-notation.
allowed-tools: Read, Write, Edit, Bash
---

# Dry-Monads Patterns

## Overview

**Status**: MANDATORY for all service objects  
**Location**: `app/services/`

dry-monads provides railway-oriented programming with `Success` and `Failure` monads, enabling clean error handling without exceptions.

## Why We Use dry-monads

- ✅ **Explicit success/failure paths** - No hidden control flow
- ✅ **Composable operations** - Chain operations with `do` notation
- ✅ **Type safety** - Clear contracts for success/failure data
- ✅ **Industry standard** - Well-maintained, battle-tested gem
- ✅ **Pattern matching** - Ruby 3+ pattern matching support

## Installation

Add to Gemfile:

```ruby
gem 'dry-monads', '~> 1.6'
```

## Project Structure

```
app/services/
├── competitions/
│   ├── create_from_template.rb   # Competitions::CreateFromTemplate
│   └── duplicate.rb              # Competitions::Duplicate
├── incidents/
│   ├── create.rb                 # Incidents::Create
│   └── officialize.rb            # Incidents::Officialize
├── reports/
│   ├── create.rb                 # Reports::Create
│   └── attach_to_incident.rb     # Reports::AttachToIncident
└── races/
    ├── start.rb                  # Races::Start
    └── complete.rb               # Races::Complete

spec/services/
└── (mirrors app/services structure)
```

## Basic Pattern

### Include the Monad

```ruby
# app/services/incidents/create.rb
module Incidents
  class Create
    include Dry::Monads[:result, :do]
    
    def call(user:, params:)
      # Your implementation
    end
  end
end
```

**What this gives you:**
- `Success(value)` - Wrap successful results
- `Failure(error)` - Wrap failures
- `yield` - Unwrap Success, short-circuit on Failure (do-notation)

## Core Patterns

### Pattern 1: Simple Success/Failure

```ruby
# app/services/incidents/officialize.rb
module Incidents
  class Officialize
    include Dry::Monads[:result]
    
    def call(user:, incident_id:)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized"]) unless user.jury_president?
      
      incident = Incident.find_by(id: incident_id)
      return Failure([:not_found, "Incident not found"]) unless incident
      return Failure([:already_official, "Already official"]) if incident.official?
      
      incident.update!(status: :official)
      Success(incident)
    rescue ActiveRecord::RecordInvalid => e
      Failure([:update_failed, e.message])
    end
  end
end

# Usage
result = Incidents::Officialize.new.call(user: current_user, incident_id: 123)

case result
in Success(incident)
  puts "Officialized: #{incident.id}"
in Failure([:not_found, message])
  puts "Not found: #{message}"
in Failure([:forbidden, message])
  puts "Forbidden: #{message}"
in Failure([code, message])
  puts "Error (#{code}): #{message}"
end
```

### Pattern 2: Do-Notation (Railway Pattern)

**Best for chaining multiple operations:**

```ruby
# app/services/incidents/create.rb
module Incidents
  class Create
    include Dry::Monads[:result, :do]
    
    def call(user:, params:)
      _         = yield authorize!(user)
      validated = yield validate!(params)
      race      = yield find_race!(validated[:race_id])
      location  = yield find_location(validated[:race_location_id])
      incident  = yield persist!(race: race, location: location, params: validated)
      
      Success(incident)
    end
    
    private
    
    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized"]) unless user.referee? || user.admin?
      Success(user)
    end
    
    def validate!(params)
      errors = {}
      errors[:race_id] = ["can't be blank"] if params[:race_id].blank?
      errors.any? ? Failure([:validation_failed, errors]) : Success(params.to_h.symbolize_keys)
    end
    
    def find_race!(race_id)
      race = Race.find_by(id: race_id)
      race ? Success(race) : Failure([:not_found, "Race not found"])
    end
    
    def find_location(race_location_id)
      return Success(nil) if race_location_id.blank?
      location = RaceLocation.find_by(id: race_location_id)
      location ? Success(location) : Failure([:not_found, "Location not found"])
    end
    
    def persist!(race:, location:, params:)
      incident = Incident.new(
        race: race,
        race_location: location,
        description: params[:description],
        status: :unofficial
      )
      incident.save ? Success(incident) : Failure([:save_failed, incident.errors.to_h])
    end
  end
end
```

**How `yield` works:**
- If result is `Success(value)`, extracts `value` and continues
- If result is `Failure(error)`, immediately returns `Failure(error)` (short-circuit)

### Pattern 3: Service with Transaction

```ruby
# app/services/competitions/create_from_template.rb
module Competitions
  class CreateFromTemplate
    include Dry::Monads[:result, :do]
    
    def call(template:, attributes:, race_type_ids: nil)
      template    = yield find_template(template)
      race_types  = yield resolve_race_types(template, race_type_ids)
      validated   = yield validate_attributes(attributes)
      competition = yield create_competition(template, validated, race_types)
      
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
        types.any? ? Success(types) : Failure([:no_race_types, "No matching race types"])
      else
        Success(template.race_types)
      end
    end
    
    def validate_attributes(attributes)
      required = %i[name place country start_date end_date]
      missing = required.select { |key| attributes[key].blank? }
      missing.any? ? Failure([:validation_failed, { missing_fields: missing }]) : Success(attributes)
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

## Controller Integration

### Standard Pattern

```ruby
class IncidentsController < ApplicationController
  def create
    result = Incidents::Create.new.call(
      user: current_user,
      params: incident_params
    )
    
    case result
    in Success(incident)
      redirect_to incident, notice: 'Incident created successfully'
    in Failure([:validation_failed, errors])
      @errors = errors
      render :new, status: :unprocessable_entity
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

### With Detailed Error Handling

```ruby
class CompetitionsController < ApplicationController
  def create
    result = Competitions::CreateFromTemplate.new.call(
      template: params[:template_id],
      attributes: competition_params,
      race_type_ids: params[:race_type_ids]
    )
    
    case result
    in Success(competition)
      redirect_to competition, notice: "Competition created"
    in Failure([:not_found, message])
      redirect_to new_competition_path, alert: message
    in Failure([:validation_failed, errors])
      @errors = errors
      render :new, status: :unprocessable_entity
    in Failure([:record_invalid, message])
      flash[:error] = "Error: #{message}"
      render :new, status: :unprocessable_entity
    in Failure([code, message])
      Rails.logger.error("Competition creation failed: #{code} - #{message}")
      redirect_to competitions_path, alert: 'An error occurred'
    end
  end
end
```

## Testing Patterns

### Basic Spec

```ruby
# spec/services/incidents/create_spec.rb
require 'rails_helper'

RSpec.describe Incidents::Create do
  subject(:service) { described_class.new }
  
  let(:user) { create(:user, :referee) }
  let(:race) { create(:race) }
  let(:params) { { race_id: race.id, description: 'Test incident' } }
  
  describe '#call' do
    context 'with valid params and authorized user' do
      it 'returns Success with incident' do
        result = service.call(user: user, params: params)
        
        expect(result).to be_success
        expect(result.success).to be_a(Incident)
        expect(result.success.description).to eq('Test incident')
      end
      
      it 'creates an incident record' do
        expect {
          service.call(user: user, params: params)
        }.to change(Incident, :count).by(1)
      end
    end
    
    context 'with unauthorized user' do
      let(:user) { create(:user, :broadcast_viewer) }
      
      it 'returns Failure with forbidden' do
        result = service.call(user: user, params: params)
        
        expect(result).to be_failure
        
        case result
        in Failure([:forbidden, message])
          expect(message).to include('Not authorized')
        else
          fail "Expected forbidden failure, got #{result}"
        end
      end
    end
    
    context 'with invalid params' do
      let(:params) { { description: 'Missing race_id' } }
      
      it 'returns Failure with validation errors' do
        result = service.call(user: user, params: params)
        
        expect(result).to be_failure
        
        case result
        in Failure([:validation_failed, errors])
          expect(errors).to have_key(:race_id)
        else
          fail "Expected validation_failed, got #{result}"
        end
      end
    end
  end
end
```

## Failure Code Conventions

Use consistent failure codes across the project:

| Code | Meaning | Example |
|------|---------|---------|
| `:unauthorized` | User not logged in | `Failure([:unauthorized, "Must be logged in"])` |
| `:forbidden` | User lacks permission | `Failure([:forbidden, "Not authorized"])` |
| `:not_found` | Record doesn't exist | `Failure([:not_found, "Race not found"])` |
| `:validation_failed` | Input validation failed | `Failure([:validation_failed, { name: ["can't be blank"] }])` |
| `:save_failed` | ActiveRecord save failed | `Failure([:save_failed, record.errors.to_h])` |
| `:record_invalid` | Transaction failed | `Failure([:record_invalid, e.message])` |
| `:already_exists` | Duplicate record | `Failure([:already_exists, "Already exists"])` |

## Common Mistakes

### ❌ Mistake 1: Not including :do

```ruby
class MyService
  include Dry::Monads[:result]  # Missing :do!
  
  def call
    user = yield find_user  # ERROR: yield without :do notation
    Success(user)
  end
end
```

**Fix:**

```ruby
class MyService
  include Dry::Monads[:result, :do]  # Include :do
  
  def call
    user = yield find_user
    Success(user)
  end
end
```

### ❌ Mistake 2: Mixing exceptions with monads

```ruby
def call
  user = yield find_user
  raise "Invalid user" unless user.valid?  # BAD: mixing paradigms
  Success(user)
end
```

**Fix:**

```ruby
def call
  user = yield find_user
  return Failure([:invalid_user, "User is invalid"]) unless user.valid?
  Success(user)
end
```

### ❌ Mistake 3: Not handling Failure in controller

```ruby
# BAD: Assumes always success
def create
  result = MyService.new.call(params: params)
  redirect_to result.success  # Crashes on Failure!
end
```

**Fix:**

```ruby
def create
  result = MyService.new.call(params: params)
  
  case result
  in Success(data)
    redirect_to data
  in Failure([code, message])
    redirect_to fallback_path, alert: message
  end
end
```

### ❌ Mistake 4: Inconsistent return types

```ruby
# BAD: Returns boolean and monad
def call(params:)
  return false unless valid?(params)  # Returns boolean
  Success(create_record(params))       # Returns monad
end
```

**Fix:**

```ruby
# GOOD: Always return monad
def call(params:)
  return Failure([:invalid, "Invalid params"]) unless valid?(params)
  Success(create_record(params))
end
```

## Quick Reference

| Operation | Code | Returns |
|-----------|------|---------|
| Wrap success | `Success(value)` | `Success<T>` |
| Wrap failure | `Failure(error)` | `Failure<E>` |
| Check if success | `result.success?` | `true/false` |
| Check if failure | `result.failure?` | `true/false` |
| Unwrap success | `result.success` or `result.value!` | `T` or raises |
| Unwrap failure | `result.failure` | `E` |
| Chain operations | `yield result` | Unwrap or short-circuit |

## Decision Tree

```
Should I use dry-monads for this?
├─ Is it a service object in app/services/? → YES, use dry-monads
├─ Complex business logic with multiple steps? → YES, use dry-monads with :do
├─ Simple model method? → NO, use standard Ruby
└─ Controller action? → NO, but call services that use dry-monads
```

## References

- **Official docs**: https://dry-rb.org/gems/dry-monads/
- **Architecture overview**: [docs/architecture-overview.md](../../../docs/architecture-overview.md)
- **Service agent**: [.agents/service.md](../../service.md)
- **Railway Oriented Programming**: https://fsharpforfunandprofit.com/rop/

---

**Status**: MANDATORY  
**Version**: 2.0  
**Last Updated**: 2025-01  
**Project**: ISMF Race Logger