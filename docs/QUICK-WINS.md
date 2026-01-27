# Quick Wins - Fix Test Failures Fast

**Goal**: Get from 518 failures to <100 failures in 1-2 days  
**Current Status**: 619 examples, 518 failures (101 passing)

---

## Quick Win #1: Fix MagicLink (28 failures) ⭐

**Time**: 2-3 hours  
**Impact**: 28 tests passing  
**Difficulty**: Easy

### Problem
`Infrastructure::Persistence::Records::MagicLinkRecord` not properly implemented.

### Fix Steps

1. **Check the model file**:
```bash
# Check if file exists and structure
cat app/infrastructure/persistence/records/magic_link_record.rb
```

2. **Ensure proper structure**:
```ruby
# app/infrastructure/persistence/records/magic_link_record.rb
module Infrastructure
  module Persistence
    module Records
      class MagicLinkRecord < ApplicationRecord
        self.table_name = "magic_links"
        
        # Associations
        belongs_to :user, 
                   class_name: "Infrastructure::Persistence::Records::UserRecord",
                   foreign_key: "user_id"
        
        # Validations
        validates :token, presence: true, uniqueness: true
        validates :expires_at, presence: true
        
        # Callbacks
        before_validation :generate_token, on: :create, if: -> { token.blank? }
        before_validation :set_expiry, on: :create, if: -> { expires_at.blank? }
        
        # Scopes
        scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
        scope :expired, -> { where("expires_at <= ?", Time.current) }
        scope :used, -> { where.not(used_at: nil) }
        
        # Instance methods
        def expired?
          expires_at <= Time.current
        end
        
        def used?
          used_at.present?
        end
        
        def valid_for_use?
          !expired? && !used?
        end
        
        def consume!
          return false unless valid_for_use?
          
          update(used_at: Time.current)
        end
        
        # Class methods
        def self.find_and_consume(token)
          link = valid.find_by(token: token)
          return nil unless link
          
          link.consume! ? link : nil
        end
        
        private
        
        def generate_token
          self.token = SecureRandom.urlsafe_base64(32)
        end
        
        def set_expiry
          self.expires_at = 15.minutes.from_now
        end
      end
    end
  end
end
```

3. **Add method to UserRecord**:
```ruby
# app/infrastructure/persistence/records/user_record.rb
# Add this method:

def generate_magic_link!
  magic_links.create!
end
```

4. **Run tests**:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure/persistence/records/magic_link_spec.rb
```

**Expected Result**: 28 examples, 0 failures ✅

---

## Quick Win #2: Fix Policy Specs (400+ failures) ⭐⭐⭐

**Time**: 4-6 hours  
**Impact**: 400+ tests passing  
**Difficulty**: Tedious but straightforward

### Problem
Policy specs reference old `User` model instead of `Infrastructure::Persistence::Records::UserRecord`.

### Strategy
Search and replace across all policy specs:

1. **Pattern to find**:
```ruby
# Old pattern
User.create!(...)
user = User.find(...)
@user = User.create!(...)

# Also old
role = Role.create!(...)
```

2. **Replace with**:
```ruby
# New pattern
Infrastructure::Persistence::Records::UserRecord.create!(...)
user = Infrastructure::Persistence::Records::UserRecord.find(...)
@user = Infrastructure::Persistence::Records::UserRecord.create!(...)

# Also new
role = Infrastructure::Persistence::Records::RoleRecord.create!(...)
```

### Files to Update

```bash
spec/policies/application_policy_spec.rb
spec/policies/competition_policy_spec.rb
spec/policies/incident_policy_spec.rb
spec/policies/race_policy_spec.rb
spec/policies/race_location_policy_spec.rb
spec/policies/race_type_policy_spec.rb
spec/policies/report_policy_spec.rb
spec/policies/stage_policy_spec.rb
```

### Automated Approach

```bash
cd ismf-race-logger

# For User references
find spec/policies -name "*.rb" -exec sed -i '' 's/User\.create/Infrastructure::Persistence::Records::UserRecord.create/g' {} \;
find spec/policies -name "*.rb" -exec sed -i '' 's/User\.find/Infrastructure::Persistence::Records::UserRecord.find/g' {} \;

# For Role references
find spec/policies -name "*.rb" -exec sed -i '' 's/Role\.create/Infrastructure::Persistence::Records::RoleRecord.create/g' {} \;
find spec/policies -name "*.rb" -exec sed -i '' 's/Role\.find/Infrastructure::Persistence::Records::RoleRecord.find/g' {} \;
```

### Manual Approach (Example)

**Before**:
```ruby
# spec/policies/application_policy_spec.rb
let(:admin_user) do
  User.create!(
    email_address: 'admin@example.com',
    name: 'Admin User',
    password: 'password123',
    admin: true
  )
end

let(:referee_role) { Role.create!(name: 'national_referee') }
```

**After**:
```ruby
# spec/policies/application_policy_spec.rb
let(:admin_user) do
  Infrastructure::Persistence::Records::UserRecord.create!(
    email_address: 'admin@example.com',
    name: 'Admin User',
    password: 'password123',
    password_confirmation: 'password123',
    admin: true
  )
end

let(:referee_role) do
  Infrastructure::Persistence::Records::RoleRecord.create!(name: 'national_referee')
end
```

**Note**: Also add `password_confirmation` where `password` is set!

### Test One File First

```bash
# Test application_policy_spec first
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/policies/application_policy_spec.rb
```

Once that passes, run all policies:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/policies
```

**Expected Result**: 400+ examples, 0 failures ✅

---

## Quick Win #3: Fix Remaining Infrastructure (50 failures)

**Time**: 2-4 hours  
**Impact**: 50 tests passing  
**Difficulty**: Medium

### Problem
Other infrastructure specs may reference old models or have incomplete implementations.

### Steps

1. **Identify failures**:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure --format failures
```

2. **Common issues**:
   - References to `User` instead of `UserRecord`
   - References to `Session` instead of `SessionRecord`
   - Missing associations
   - Missing validations

3. **Fix pattern**: Same as policies - replace old class names with new namespaced ones.

---

## Quick Win #4: Fix Web Layer Basics (20 failures)

**Time**: 2-3 hours  
**Impact**: 20 tests passing  
**Difficulty**: Medium

### Problem
Controllers or controller specs referencing old models.

### Steps

1. **Check which specs are failing**:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web --format failures
```

2. **Common fixes**:
   - Update factory/fixture references to use `UserRecord`
   - Ensure controllers use `Operations::Commands::*` properly
   - Fix session handling

3. **SessionsController** should already be mostly working. Focus on:
   - Admin controllers
   - Other CRUD controllers

---

## Verification Strategy

### After Each Quick Win

1. **Run the specific test suite**:
```bash
# After MagicLink fix
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure/persistence/records/magic_link_spec.rb

# After policies fix
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/policies

# After infrastructure fix
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure

# After web fix
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web
```

2. **Run full suite to check overall progress**:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format progress
```

3. **Check final count**:
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec | grep "examples"
```

---

## Expected Progress

| Stage | Failures | Passing | % Complete |
|-------|----------|---------|------------|
| **Current** | 518 | 101 | 16% |
| After MagicLink | 490 | 129 | 21% |
| After Policies | 90 | 529 | 85% |
| After Infrastructure | 40 | 579 | 94% |
| After Web | 20 | 599 | 97% |
| **Target** | <20 | 599+ | >97% |

---

## Common Pitfalls

### 1. Forgetting password_confirmation
```ruby
# ❌ Will fail validation
UserRecord.create!(
  email_address: 'user@example.com',
  password: 'password123'
)

# ✅ Correct
UserRecord.create!(
  email_address: 'user@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)
```

### 2. Wrong namespace
```ruby
# ❌ Old
User.create!(...)

# ❌ Also wrong
Persistence::Records::UserRecord.create!(...)

# ✅ Correct
Infrastructure::Persistence::Records::UserRecord.create!(...)
```

### 3. Forgetting associations
```ruby
# ❌ May fail if user_id not set
magic_link = MagicLinkRecord.create!(token: 'abc')

# ✅ Correct
user = UserRecord.create!(...)
magic_link = user.magic_links.create!
```

### 4. Missing table_name for Records
```ruby
# ❌ Will look for "infrastructure_persistence_records_users" table
class UserRecord < ApplicationRecord
end

# ✅ Correct
class UserRecord < ApplicationRecord
  self.table_name = "users"
end
```

---

## Pro Tips

### 1. Use Grep to Find Issues
```bash
# Find all references to old User model in specs
grep -r "User\." spec/ --exclude-dir=infrastructure

# Find all references to Role model
grep -r "Role\." spec/

# Find password without confirmation
grep -r "password:" spec/ | grep -v "password_confirmation"
```

### 2. Fix Files in Order
Start with files that have the most failures:
```bash
# Count failures per file
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec --format json | jq '.examples[] | select(.status == "failed") | .file_path' | sort | uniq -c | sort -rn
```

### 3. Create Helper Method
Add to `spec/support/record_helpers.rb`:
```ruby
module RecordHelpers
  def create_user(**attrs)
    Infrastructure::Persistence::Records::UserRecord.create!(
      email_address: attrs[:email_address] || 'user@example.com',
      name: attrs[:name] || 'Test User',
      password: attrs[:password] || 'password123',
      password_confirmation: attrs[:password] || 'password123',
      **attrs
    )
  end
  
  def create_role(name:)
    Infrastructure::Persistence::Records::RoleRecord.create!(name: name)
  end
end

RSpec.configure do |config|
  config.include RecordHelpers
end
```

Then in specs:
```ruby
# Instead of long Infrastructure::Persistence::Records::UserRecord.create!(...)
let(:user) { create_user(email_address: 'test@example.com') }
let(:admin) { create_user(admin: true) }
let(:referee_role) { create_role(name: 'national_referee') }
```

---

## Success Criteria

After completing all quick wins:

- ✅ MagicLink tests: 28 examples, 0 failures
- ✅ Policy tests: 400+ examples, 0 failures
- ✅ Infrastructure tests: 200+ examples, <5 failures
- ✅ Web tests: 90+ examples, <10 failures
- ✅ **Total: 619 examples, <20 failures (>97% passing)**

---

## Next Steps After Quick Wins

Once you're at >97% passing:

1. **Fix remaining edge cases** (1-2 days)
   - Address specific failing tests one by one
   - Likely missing repositories or incomplete implementations

2. **Add missing features** (1 week)
   - Implement repositories for all entities
   - Create operations commands/queries for all controllers
   - Complete web layer migration

3. **Polish & document** (3-5 days)
   - Fix Packwerk violations
   - Complete documentation
   - Add CI checks
   - Clean up deprecated code

4. **Ship it!** 🚀
   - Full test suite passing
   - Hanami-compatible architecture complete
   - Ready for production

---

## Getting Help

If you get stuck:

1. Check `docs/REFACTOR-STATUS-2024.md` for overall status
2. Check `docs/architecture/namespace-migration-operations.md` for namespace details
3. Check `CLAUDE.md` for project guidelines
4. Run `docker compose exec app bin/rails console` to test code interactively

---

**Ready to start? Begin with Quick Win #1 (MagicLink)!** ⭐

Run this to get started:
```bash
docker compose exec app cat app/infrastructure/persistence/records/magic_link_record.rb
```
