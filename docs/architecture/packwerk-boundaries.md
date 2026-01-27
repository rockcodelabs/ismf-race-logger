# Packwerk Boundaries - Architectural Enforcement

## Overview

This document defines the architectural boundaries enforced by Packwerk in the ISMF Race Logger application. Packwerk ensures that our Hanami-compatible architecture remains intact by preventing unauthorized dependencies between layers.

## Package Structure

```
ismf-race-logger/
├── app/
│   ├── domain/          (Package 1)
│   ├── application/     (Package 2)
│   ├── infrastructure/  (Package 3)
│   └── web/             (Package 4)
```

## Dependency Rules

### Allowed Dependencies (Downward Flow)

```
┌─────────────────┐
│      WEB        │ ─┐
└─────────────────┘  │
                     │
┌─────────────────┐  │  Can depend on
│  APPLICATION    │ ◄┘  both Application
└─────────────────┘     and Domain
         │
         │ Can depend on Domain only
         ▼
┌─────────────────┐
│     DOMAIN      │ ◄─── Infrastructure can
└─────────────────┘      read Domain entities
         ▲
         │ Uses for mapping
         │
┌─────────────────┐
│ INFRASTRUCTURE  │
└─────────────────┘
```

### Summary Table

| Layer          | Can Depend On         | Cannot Depend On               |
|----------------|-----------------------|--------------------------------|
| Domain         | Nothing               | Everything (must be pure)      |
| Application    | Domain                | Web, Infrastructure            |
| Infrastructure | Domain (read-only)    | Web, Application               |
| Web            | Application, Domain   | Infrastructure (must use app)  |

## Package Configurations

### Root Package (`package.yml`)

```yaml
enforce_dependencies: true
enforce_privacy: true
```

### Domain Package (`app/domain/package.yml`)

```yaml
# Domain is the core - depends on nothing
enforce_dependencies: true
enforce_privacy: false

dependencies: []

# Optional: Make certain modules public
public_path: entities/
```

**Rules**:
- ✅ Pure Ruby
- ✅ dry-struct, dry-types, dry-validation
- ❌ NO Rails constants
- ❌ NO ActiveRecord
- ❌ NO persistence logic
- ❌ NO HTTP concerns
- ❌ NO framework-specific code

### Application Package (`app/application/package.yml`)

```yaml
# Application orchestrates domain logic
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/domain
```

**Rules**:
- ✅ Use Domain entities
- ✅ dry-monads for control flow
- ✅ Dependency injection via dry-auto_inject
- ✅ Access Infrastructure through interfaces (dependency injection)
- ❌ NO direct Rails controller access
- ❌ NO direct ActiveRecord queries
- ❌ NO view logic

### Infrastructure Package (`app/infrastructure/package.yml`)

```yaml
# Infrastructure provides adapters
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/domain
```

**Rules**:
- ✅ ActiveRecord models (suffixed with "Record")
- ✅ ActiveJob, ActiveStorage, ActionMailer
- ✅ Map Records to Domain entities
- ✅ Read Domain entities for structure
- ❌ NO business logic
- ❌ NO validations (domain handles)
- ❌ NO callbacks for business rules
- ❌ Cannot depend on Application or Web

### Web Package (`app/web/package.yml`)

```yaml
# Web is the HTTP adapter
enforce_dependencies: true
enforce_privacy: false

dependencies:
  - app/application
  - app/domain
```

**Rules**:
- ✅ Controllers call Application commands/queries
- ✅ Read Domain entities for display
- ✅ Thin controllers (adapters only)
- ✅ Views render entities
- ❌ NO direct Infrastructure access
- ❌ NO business logic in controllers
- ❌ NO fat controllers

## Common Violations and Fixes

### Violation 1: Domain Referencing Rails

**Error**:
```
app/domain/entities/report.rb:1:0
Privacy violation: '::Rails' is private to 'app/web'
```

**Bad Code**:
```ruby
# app/domain/entities/report.rb
class Report < Dry::Struct
  def video_path
    Rails.application.routes.url_helpers.rails_blob_url(video)
  end
end
```

**Fix**:
```ruby
# app/domain/entities/report.rb
class Report < Dry::Struct
  attribute :video_url, Types::String.optional
  
  def has_video?
    !video_url.nil?
  end
end

# app/infrastructure/persistence/repositories/report_repository.rb
def to_entity(record)
  Domain::Entities::Report.new(
    # ... other attributes ...
    video_url: record.video.attached? ? 
      Rails.application.routes.url_helpers.rails_blob_url(record.video) : 
      nil
  )
end
```

### Violation 2: Web Accessing Infrastructure Directly

**Error**:
```
app/web/controllers/reports_controller.rb:10:0
Dependency violation: app/web cannot depend on app/infrastructure
```

**Bad Code**:
```ruby
# app/web/controllers/reports_controller.rb
class ReportsController < ApplicationController
  def index
    @reports = Infrastructure::Persistence::Records::ReportRecord.all
  end
end
```

**Fix**:
```ruby
# app/web/controllers/reports_controller.rb
class ReportsController < ApplicationController
  def index
    result = reports_query.call
    
    result.either(
      ->(reports) { render :index, locals: { reports: reports } },
      ->(error) { redirect_to root_path, alert: "Error loading reports" }
    )
  end
  
  private
  
  def reports_query
    ApplicationContainer.resolve("queries.reports.all")
  end
end
```

### Violation 3: Application Using ActiveRecord Directly

**Error**:
```
app/application/commands/create_report.rb:15:0
Dependency violation: app/application cannot depend on app/infrastructure
```

**Bad Code**:
```ruby
# app/application/commands/create_report.rb
class CreateReport
  def call(params)
    record = Infrastructure::Persistence::Records::ReportRecord.create!(params)
    Success(record)
  end
end
```

**Fix**:
```ruby
# app/application/commands/create_report.rb
class CreateReport
  include Import["repositories.report"]
  
  def call(params)
    report_repository.create(params)
  end
end
```

### Violation 4: Infrastructure Importing Application Code

**Error**:
```
app/infrastructure/jobs/process_report_job.rb:5:0
Dependency violation: app/infrastructure cannot depend on app/application
```

**Bad Code**:
```ruby
# app/infrastructure/jobs/process_report_job.rb
class ProcessReportJob < ApplicationJob
  def perform(report_id)
    command = Application::Commands::ProcessReport.new
    command.call(report_id)
  end
end
```

**Fix**:
```ruby
# app/infrastructure/jobs/process_report_job.rb
class ProcessReportJob < ApplicationJob
  def perform(report_id)
    # Infrastructure should handle side effects only
    # Processing logic should be in domain/application
    record = Records::ReportRecord.find(report_id)
    
    # Perform infrastructure-level task (e.g., video transcoding)
    if record.video.attached?
      record.video.variant(resize_to_limit: [1920, 1080]).processed
    end
  end
end

# OR trigger from application layer:
# app/application/commands/create_report.rb
class CreateReport
  def call(params)
    report = yield report_repository.create(params)
    
    # Trigger infrastructure job from application
    ProcessReportJob.perform_later(report.id)
    
    Success(report)
  end
end
```

## Checking Boundaries

### Run Packwerk Check

```bash
# Check all packages
docker compose exec app bundle exec packwerk check

# Check specific package
docker compose exec app bundle exec packwerk check app/domain/

# Validate package.yml files
docker compose exec app bundle exec packwerk validate
```

### Update Packwerk Cache

After adding new files or changing dependencies:

```bash
docker compose exec app bundle exec packwerk update
```

### Visualize Dependencies

Generate a dependency graph:

```bash
docker compose exec app bundle exec packwerk visualize
```

This creates a visual representation of package dependencies.

## CI/CD Integration

### Add to GitHub Actions

```yaml
# .github/workflows/packwerk.yml
name: Packwerk

on: [push, pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Run Packwerk
        run: bundle exec packwerk check
      
      - name: Validate packages
        run: bundle exec packwerk validate
```

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
#!/bin/sh

echo "Running Packwerk check..."
bundle exec packwerk check

if [ $? -ne 0 ]; then
  echo "❌ Packwerk violations detected. Please fix before committing."
  exit 1
fi

echo "✅ Packwerk check passed"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Privacy Enforcement

### Making Modules Private

If you want to hide internal implementation details:

```yaml
# app/domain/package.yml
enforce_privacy: true

public_path: entities/
```

This means:
- ✅ Other packages can access `app/domain/entities/*`
- ❌ Other packages CANNOT access `app/domain/services/*` (internal)

### Explicit Exports

For fine-grained control:

```yaml
# app/application/package.yml
enforce_privacy: true

public_path: commands/
```

Now only commands are public, queries become internal.

## Gradual Adoption

If migrating an existing codebase:

### Step 1: Generate Baseline

```bash
bundle exec packwerk update-todo
```

This creates `package_todo.yml` files with existing violations.

### Step 2: Fix Incrementally

Fix violations one at a time, removing them from `package_todo.yml`.

### Step 3: Prevent New Violations

New violations will still be caught, but existing ones are tolerated until fixed.

## Benefits of Packwerk

1. **Architectural Integrity** - Enforces layer boundaries automatically
2. **Refactoring Safety** - Catch accidental dependencies during refactoring
3. **Team Alignment** - Makes architecture explicit and enforceable
4. **Documentation** - Package structure documents intended architecture
5. **CI/CD Integration** - Fails builds on architectural violations
6. **Hanami Preparation** - Ensures clean boundaries for migration

## Troubleshooting

### Issue: False Positives

If Packwerk reports a violation that you believe is valid:

1. Check if the dependency is truly needed
2. Consider if the code is in the wrong package
3. Use `package_todo.yml` to temporarily suppress (with justification)

### Issue: Packwerk Cache Out of Sync

```bash
# Clear cache
rm -rf .packwerk_cache/

# Rebuild
bundle exec packwerk update
```

### Issue: Performance (Large Codebase)

```bash
# Run in parallel
bundle exec packwerk check --parallel
```

## Reference Links

- [Packwerk Documentation](https://github.com/Shopify/packwerk)
- [Gradual Modularization Guide](https://github.com/Shopify/packwerk/blob/main/USAGE.md)
- [Package Privacy](https://github.com/Shopify/packwerk/blob/main/USAGE.md#privacy)

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Status**: Active Enforcement