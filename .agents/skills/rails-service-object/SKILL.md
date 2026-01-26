---
name: rails-service-object
description: Service object architecture for ISMF Race Logger using dry-monads Result monad. Covers when to use services, structure patterns, testing, and integration with controllers.
allowed-tools: Read, Write, Edit, Bash
---

# Rails Service Object Pattern

## Overview

Service objects encapsulate complex business logic that doesn't belong in models or controllers.

**Project Standard**: All services MUST use dry-monads (`Success`/`Failure`) and live in `app/services/`.

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
├── competitions/
│   ├── create_from_template_spec.rb
│   └── duplicate_spec.rb
└── ...
```

## When to Use Service Objects

| Scenario | Use Service Object? | Alternative |
|----------|---------------------|-------------|
| Multiple model interactions | ✅ Yes | - |
| Complex business logic | ✅ Yes | - |
| External API calls | ✅ Yes | - |
| Multi-step operations | ✅ Yes | - |
| Transaction required | ✅ Yes | - |
| Simple CRUD | ❌ No | Use model directly |
| Single validation | ❌ No | Use model validation |
| View formatting | ❌ No | Use presenter/helper |

## Decision Tree

```
Where should this logic go?

Is it business logic?
├─ No → Controller/View/Helper
└─ Yes → Continue...

Does it involve multiple models?
├─ Yes → Service Object
└─ No → Continue...

Is it complex (>10 lines)?
├─ Yes → Service Object
└─ No → Model method

Does it call external APIs?
├─ Yes → Service Object
└─ No → Continue...

Does it need transaction?
├─ Yes → Service Object
└─ No → Model method
```

## Naming Convention

**Pattern**: `Namespace::Action`

Examples:
- `Competitions::CreateFromTemplate`
- `Competitions::Duplicate`
- `Incidents::Create`
- `Incidents::Officialize`
- `Reports::AttachToIncident`

## Basic Template

```ruby
# app/services/incidents/create.rb
module Incidents
  class Create
    include Dry::Monads[:result, :do]

    def call(user:, params:)
      _         = yield authorize!(user)
      validated = yield validate!(params)
      race      = yield find_race!(validated[:race_id])
      incident  = yield persist!(race: race, params: validated)
      
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

    def persist!(race:, params:)
      incident = Incident.new(race: race, description: params[:description], status: :unofficial)
      incident.save ? Success(incident) : Failure([:save_failed, incident.errors.to_h])
    end
  end
end
```

## Patterns

### Pattern 1: Simple CRUD Service

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
      report    = yield persist!(user: user, race: race, rule: rule, params: validated)

      Success(report)
    end

    private

    def authorize!(user)
      return Failure([:unauthorized, "Must be logged in"]) unless user
      return Failure([:forbidden, "Not authorized"]) unless user.referee? || user.var_operator?
      Success(user)
    end

    def validate!(params)
      errors = {}
      errors[:race_id] = ["can't be blank"] if params[:race_id].blank?
      errors[:rule_id] = ["can't be blank"] if params[:rule_id].blank?
      errors.any? ? Failure([:validation_failed, errors]) : Success(params.to_h.symbolize_keys)
    end

    def find_race!(race_id)
      race = Race.find_by(id: race_id)
      race ? Success(race) : Failure([:not_found, "Race not found"])
    end

    def find_rule!(rule_id)
      rule = Rule.find_by(id: rule_id)
      rule ? Success(rule) : Failure([:not_found, "Rule not found"])
    end

    def persist!(user:, race:, rule:, params:)
      report = Report.new(
        user: user,
        race: race,
        rule: rule,
        description: params[:description],
        status: :draft
      )
      report.save ? Success(report) : Failure([:save_failed, report.errors.to_h])
    end
  end
end
```

### Pattern 2: Service with Transaction

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

### Pattern 3: State Transition Service

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
      return Failure([:forbidden, "Only jury president can officialize"]) unless user.jury_president?
      Success(user)
    end

    def find_incident!(incident_id)
      incident = Incident.find_by(id: incident_id)
      incident ? Success(incident) : Failure([:not_found, "Incident not found"])
    end

    def validate_can_officialize!(incident)
      incident.official? ? Failure([:already_official, "Already official"]) : Success(incident)
    end

    def officialize!(incident)
      incident.update(status: :official) ? Success(incident) : Failure([:update_failed, incident.errors.to_h])
    end
  end
end
```

### Pattern 4: Multi-Record Service

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
      return Failure([:not_found, "No reports found"]) if reports.empty?
      return Failure([:invalid_reports, "Reports must belong to same race"]) if reports.map(&:race_id).uniq.size > 1
      Success(reports)
    end

    def resolve_incident!(incident_id, new_incident_params, race)
      if incident_id.present?
        incident = Incident.find_by(id: incident_id)
        incident ? Success(incident) : Failure([:not_found, "Incident not found"])
      elsif new_incident_params.present?
        incident = Incident.new(race: race, description: new_incident_params[:description], status: :unofficial)
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
      redirect_to competition, notice: 'Competition created'
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

## Testing

### Basic Service Spec

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

      it 'does not create an incident' do
        expect {
          service.call(user: user, params: params)
        }.not_to change(Incident, :count)
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

    context 'with non-existent race' do
      let(:params) { { race_id: 99999, description: 'Test' } }

      it 'returns Failure with not_found' do
        result = service.call(user: user, params: params)

        expect(result).to be_failure

        case result
        in Failure([:not_found, message])
          expect(message).to include('Race')
        else
          fail "Expected not_found, got #{result}"
        end
      end
    end
  end
end
```

### Testing Transactions

```ruby
# spec/services/competitions/create_from_template_spec.rb
require 'rails_helper'

RSpec.describe Competitions::CreateFromTemplate do
  subject(:service) { described_class.new }

  let(:template) { create(:competition_template, :with_stages_and_races) }
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
        result = service.call(template: template, attributes: valid_attributes)

        expect(result).to be_success
        expect(result.success).to be_a(Competition)
        expect(result.success.name).to eq("Test Competition 2025")
      end

      it 'creates competition with stages and races' do
        result = service.call(template: template, attributes: valid_attributes)
        competition = result.success

        expect(competition.stages.count).to eq(template.stage_templates.count)
      end
    end

    context 'when transaction fails' do
      before do
        allow(Competition).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Competition.new))
      end

      it 'returns Failure with record_invalid' do
        result = service.call(template: template, attributes: valid_attributes)

        expect(result).to be_failure

        case result
        in Failure([:record_invalid, _])
          # Expected
        else
          fail "Expected record_invalid, got #{result}"
        end
      end

      it 'does not create any records (rollback)' do
        expect {
          service.call(template: template, attributes: valid_attributes)
        }.not_to change(Competition, :count)
      end
    end
  end
end
```

## Best Practices

### ✅ Always Do

- Use dry-monads `Success`/`Failure`
- Use do-notation for chaining (`yield`)
- Write comprehensive tests
- Follow single responsibility
- Handle all error cases
- Use descriptive failure codes like `[:not_found, message]`
- Place services in `app/services/domain/action.rb`

### ⚠️ Ask First

- Modifying existing services used by multiple controllers
- Adding external API dependencies
- Changing service interfaces
- Adding database transactions

### 🚫 Never Do

- Mix exceptions with monads (use one pattern consistently)
- Create services without tests
- Put presentation logic in services
- Skip error handling
- Create "god" services with too many responsibilities

## Common Mistakes

### ❌ Mistake 1: Not using :do notation

```ruby
# ❌ Wrong - verbose
def call(params:)
  validation_result = validate(params)
  return validation_result if validation_result.failure?
  
  persist_result = persist(validation_result.success)
  return persist_result if persist_result.failure?
  
  persist_result
end
```

**Fix:**
```ruby
# ✅ Correct - clean with :do
def call(params:)
  validated = yield validate(params)
  record    = yield persist(validated)
  Success(record)
end
```

### ❌ Mistake 2: Returning inconsistent types

```ruby
# ❌ Wrong - inconsistent returns
def call(params:)
  return false unless valid?(params)  # Returns boolean
  Success(create_record(params))       # Returns monad
end
```

**Fix:**
```ruby
# ✅ Correct - always return monad
def call(params:)
  return Failure([:invalid, "Invalid params"]) unless valid?(params)
  Success(create_record(params))
end
```

### ❌ Mistake 3: Not handling Failure in controller

```ruby
# ❌ Wrong - Assumes always success
def create
  result = MyService.new.call(params: params)
  redirect_to result.success  # CRASHES on Failure!
end
```

**Fix:**
```ruby
# ✅ Correct - Handle both cases
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

## Quick Reference

| Pattern | Use Case | Example |
|---------|----------|---------|
| Simple do-notation | Multi-step success path | Creating incidents |
| With transaction | Multi-model changes | Creating from template |
| State transition | Changing status | Officializing incidents |
| Multi-record | Batch operations | Attaching reports |

## Additional Resources

- **dry-monads patterns**: See [dry-monads-patterns skill](../dry-monads-patterns/SKILL.md)
- **Testing standards**: See [testing-standards skill](../testing-standards/SKILL.md)
- **Architecture overview**: See [docs/architecture-overview.md](../../docs/architecture-overview.md)
- **Official dry-rb**: https://dry-rb.org/gems/dry-monads/

---

**Version**: 2.0  
**Last Updated**: 2025-01  
**Project**: ISMF Race Logger