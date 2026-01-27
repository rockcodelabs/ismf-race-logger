# Spec Migration Guide - Hanami-Compatible Architecture

## Overview

This guide explains how to migrate existing RSpec tests from traditional Rails structure to our Hanami-compatible layered architecture. Tests are organized by layer to ensure fast, isolated testing.

## New Spec Directory Structure

```
spec/
├── domain/                          # Fast unit tests (NO database)
│   ├── entities/
│   │   └── user_spec.rb            # ~2ms per test
│   ├── value_objects/
│   │   └── user_role_spec.rb
│   └── contracts/
│       └── authenticate_user_contract_spec.rb
│
├── application/                     # Integration tests (WITH database)
│   ├── commands/
│   │   └── users/
│   │       └── authenticate_spec.rb # ~50ms per test
│   └── queries/
│       └── users/
│           ├── find_spec.rb
│           └── all_spec.rb
│
├── infrastructure/                  # Repository tests (WITH database)
│   └── persistence/
│       └── repositories/
│           └── user_repository_spec.rb
│
└── web/                            # Request specs (full stack)
    └── controllers/
        └── sessions_controller_spec.rb # ~100ms per test
```

## Migration Mapping

### Old → New Structure

| Old Location | New Location | Layer | Database? | Speed |
|--------------|--------------|-------|-----------|-------|
| `spec/models/user_spec.rb` | `spec/domain/entities/user_spec.rb` | Domain | NO | ~2ms |
| `spec/models/role_spec.rb` | `spec/domain/value_objects/user_role_spec.rb` | Domain | NO | ~2ms |
| `spec/requests/sessions_spec.rb` | `spec/web/controllers/sessions_controller_spec.rb` | Web | YES | ~100ms |
| N/A (new) | `spec/application/commands/users/authenticate_spec.rb` | Application | YES | ~50ms |
| N/A (new) | `spec/infrastructure/persistence/repositories/user_repository_spec.rb` | Infrastructure | YES | ~50ms |

## Test Speed Strategy

### Priority: Fast Tests

```
Domain Tests (NO DB)     →  90% of tests  →  ~2ms each   →  Total: ~1s
Application Tests (DB)   →   7% of tests  →  ~50ms each  →  Total: ~2s
Infrastructure Tests (DB) →   2% of tests  →  ~50ms each  →  Total: ~1s
Web Tests (Full Stack)   →   1% of tests  →  ~100ms each →  Total: ~1s
                                             ────────────────────────
                                             Total Suite: ~5s
```

### Goal: 1000 tests in <10 seconds

## Migration Examples

### Example 1: User Model → User Entity

**Before** (`spec/models/user_spec.rb`):

```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#admin?' do
    it 'returns true for admin users' do
      user = create(:user, :admin)  # Database hit!
      expect(user.admin?).to be true
    end
  end
end
```

**After** (`spec/domain/entities/user_spec.rb`):

```ruby
require 'rails_helper'

RSpec.describe Domain::Entities::User do
  describe '#admin?' do
    it 'returns true for admin users' do
      user = described_class.new(  # NO database!
        email_address: 'admin@example.com',
        name: 'Admin',
        admin: true
      )
      
      expect(user.admin?).to be true
    end
  end
end
```

**Speed Improvement**: 200ms → 2ms (100x faster!)

### Example 2: Authentication Logic

**Before** (mixed in controller/model):

```ruby
# spec/requests/sessions_spec.rb
RSpec.describe 'Sessions', type: :request do
  it 'authenticates user' do
    user = create(:user, password: 'test123')
    post session_path, params: { 
      email_address: user.email_address, 
      password: 'test123' 
    }
    expect(response).to redirect_to(root_path)
  end
end
```

**After** (separated by layer):

```ruby
# spec/domain/entities/user_spec.rb (business logic - NO DB)
RSpec.describe Domain::Entities::User do
  it 'has role checking methods' do
    user = described_class.new(
      email_address: 'ref@example.com',
      name: 'Referee',
      role_name: 'national_referee'
    )
    expect(user.referee?).to be true
  end
end

# spec/application/commands/users/authenticate_spec.rb (use case - WITH DB)
RSpec.describe Application::Commands::Users::Authenticate do
  it 'authenticates with valid credentials' do
    user_record = Infrastructure::Persistence::Records::UserRecord.create!(
      email_address: 'user@example.com',
      password: 'test123'
    )
    
    command = described_class.new
    result = command.call(
      email_address: 'user@example.com',
      password: 'test123'
    )
    
    expect(result).to be_success
    expect(result.value!).to be_a(Domain::Entities::User)
  end
end

# spec/web/controllers/sessions_controller_spec.rb (HTTP interface - WITH DB)
RSpec.describe Web::Controllers::SessionsController, type: :request do
  it 'creates session with valid credentials' do
    user_record = Infrastructure::Persistence::Records::UserRecord.create!(
      email_address: 'user@example.com',
      password: 'test123'
    )
    
    post session_path, params: {
      email_address: 'user@example.com',
      password: 'test123'
    }
    
    expect(response).to redirect_to(root_path)
  end
end
```

**Result**: 
- Domain test: 2ms (pure logic)
- Application test: 50ms (authentication flow)
- Web test: 100ms (full HTTP stack)
- Total: 152ms vs. 200ms for single test before

But now you have **3 tests** covering different concerns!

## Layer-Specific Patterns

### Domain Layer Tests (NO Database)

**Characteristics**:
- ✅ Pure Ruby objects
- ✅ Fast (2-5ms per test)
- ✅ No database
- ✅ No Rails dependencies
- ✅ Test business logic only

**Template**:

```ruby
require 'rails_helper'

RSpec.describe Domain::Entities::User do
  describe '#can_officialize_incident?' do
    it 'returns true for admin' do
      user = described_class.new(
        email_address: 'admin@example.com',
        name: 'Admin',
        admin: true
      )

      expect(user.can_officialize_incident?).to be true
    end

    it 'returns true for referee' do
      user = described_class.new(
        email_address: 'ref@example.com',
        name: 'Referee',
        role_name: 'national_referee'
      )

      expect(user.can_officialize_incident?).to be true
    end
  end
end
```

### Application Layer Tests (WITH Database)

**Characteristics**:
- ✅ Use case testing
- ✅ Database required (minimal)
- ✅ Tests orchestration
- ✅ dry-monads Result objects
- ⚠️ ~50ms per test

**Template**:

```ruby
require 'rails_helper'

RSpec.describe Application::Commands::Users::Authenticate do
  let(:command) { described_class.new }

  describe '#call' do
    context 'with valid credentials' do
      let!(:user_record) do
        Infrastructure::Persistence::Records::UserRecord.create!(
          email_address: 'user@example.com',
          name: 'Test User',
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      it 'returns success with user entity' do
        result = command.call(
          email_address: 'user@example.com',
          password: 'password123'
        )

        expect(result).to be_success
        expect(result.value!).to be_a(Domain::Entities::User)
      end
    end

    context 'with invalid credentials' do
      it 'returns failure' do
        result = command.call(
          email_address: 'wrong@example.com',
          password: 'wrong'
        )

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end
  end
end
```

### Infrastructure Layer Tests (WITH Database)

**Characteristics**:
- ✅ Repository testing
- ✅ Database required
- ✅ Tests Record → Entity mapping
- ⚠️ ~50ms per test

**Template**:

```ruby
require 'rails_helper'

RSpec.describe Infrastructure::Persistence::Repositories::UserRepository do
  let(:repository) { described_class.new }

  describe '#find' do
    let!(:user_record) do
      Infrastructure::Persistence::Records::UserRecord.create!(
        email_address: 'user@example.com',
        name: 'Test User',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    it 'returns user entity when found' do
      result = repository.find(user_record.id)

      expect(result).to be_success
      user = result.value!
      expect(user).to be_a(Domain::Entities::User)
      expect(user.id).to eq(user_record.id)
    end

    it 'returns failure when not found' do
      result = repository.find(99999)

      expect(result).to be_failure
      expect(result.failure).to eq(:not_found)
    end
  end
end
```

### Web Layer Tests (Request Specs)

**Characteristics**:
- ✅ Full HTTP stack
- ✅ Database required
- ✅ Tests controller → command integration
- ⚠️ ~100ms per test

**Template**:

```ruby
require 'rails_helper'

RSpec.describe Web::Controllers::SessionsController, type: :request do
  describe 'POST /session' do
    let!(:user_record) do
      Infrastructure::Persistence::Records::UserRecord.create!(
        email_address: 'user@example.com',
        name: 'Test User',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    it 'creates session with valid credentials' do
      post session_path, params: {
        email_address: 'user@example.com',
        password: 'password123'
      }

      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end

    it 'rejects invalid credentials' do
      post session_path, params: {
        email_address: 'user@example.com',
        password: 'wrong'
      }

      expect(response).to redirect_to(new_session_path)
    end
  end
end
```

## Common Patterns

### Pattern 1: Testing dry-monads Results

```ruby
# Success case
result = command.call(params)
expect(result).to be_success
expect(result.value!).to eq(expected_value)

# Failure case
result = command.call(invalid_params)
expect(result).to be_failure
expect(result.failure).to eq(:error_type)

# Structured error
result = command.call(invalid_params)
expect(result).to be_failure
error_type, details = result.failure
expect(error_type).to eq(:validation_failed)
expect(details).to be_a(Hash)
```

### Pattern 2: Creating Test Entities (No DB)

```ruby
# Good - Domain test
user = Domain::Entities::User.new(
  email_address: 'test@example.com',
  name: 'Test User',
  admin: false,
  role_name: 'national_referee'
)

# Bad - Don't use factories for domain tests
user = build(:user)  # ❌ Factory ties to database
```

### Pattern 3: Creating Test Records (With DB)

```ruby
# Good - Use full namespaced record
user_record = Infrastructure::Persistence::Records::UserRecord.create!(
  email_address: 'test@example.com',
  name: 'Test User',
  password: 'password123',
  password_confirmation: 'password123'
)

# Also good - Use factories (when testing infrastructure/web)
user_record = create(:user_record)  # Factory creates Record, not Entity
```

### Pattern 4: Mocking Dependencies

```ruby
# Application layer with mocked repository
describe Application::Commands::Users::Authenticate do
  let(:mock_repository) { instance_double(Infrastructure::Persistence::Repositories::UserRepository) }
  let(:command) { described_class.new(user_repository: mock_repository) }

  it 'uses injected repository' do
    user_entity = Domain::Entities::User.new(
      id: 1,
      email_address: 'user@example.com',
      name: 'Test User',
      admin: false
    )

    allow(mock_repository).to receive(:authenticate)
      .with('user@example.com', 'password123')
      .and_return(Dry::Monads::Success(user_entity))

    result = command.call(
      email_address: 'user@example.com',
      password: 'password123'
    )

    expect(result).to be_success
  end
end
```

## Migration Checklist

### Step 1: Identify Test Type

For each existing test, determine which layer it belongs to:

- [ ] **Business logic** (role checks, calculations) → Domain
- [ ] **Use case** (authentication, creating report) → Application
- [ ] **Data persistence** (database queries) → Infrastructure
- [ ] **HTTP interface** (routes, sessions, cookies) → Web

### Step 2: Move and Rename

```bash
# Example: User model tests
mv spec/models/user_spec.rb spec/domain/entities/user_spec.rb

# Update describe block
# From: RSpec.describe User, type: :model
# To:   RSpec.describe Domain::Entities::User
```

### Step 3: Remove Database Dependencies (Domain Only)

```ruby
# Before
it 'checks admin status' do
  user = create(:user, :admin)  # Database hit
  expect(user.admin?).to be true
end

# After
it 'checks admin status' do
  user = described_class.new(admin: true)  # Pure Ruby
  expect(user.admin?).to be true
end
```

### Step 4: Update Expectations

```ruby
# Before (ActiveRecord)
expect(user).to be_valid
expect(user.errors[:email]).to include("can't be blank")

# After (dry-monads)
result = command.call(params)
expect(result).to be_success  # or be_failure
expect(result.value!).to be_a(Domain::Entities::User)
```

### Step 5: Run Tests by Layer

```bash
# Fast domain tests (NO DB)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/domain

# Application tests (WITH DB)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/application

# Infrastructure tests (WITH DB)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/infrastructure

# Web tests (full stack)
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec spec/web
```

## Factory Updates

### Old Factories (ActiveRecord)

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email_address { "user@example.com" }
    name { "Test User" }
    password { "password123" }
    
    trait :admin do
      admin { true }
    end
  end
end
```

### New Factories (Records)

```ruby
# spec/factories/user_records.rb
FactoryBot.define do
  factory :user_record, class: 'Infrastructure::Persistence::Records::UserRecord' do
    email_address { "user@example.com" }
    name { "Test User" }
    password { "password123" }
    password_confirmation { "password123" }
    
    trait :admin do
      admin { true }
    end
    
    trait :with_role do
      association :role_record, factory: :role_record
    end
  end
end
```

### Usage

```ruby
# Domain tests - NO factories (pure objects)
user = Domain::Entities::User.new(
  email_address: 'test@example.com',
  name: 'Test User'
)

# Application/Infrastructure/Web tests - Use factories
user_record = create(:user_record, :admin)
```

## Test Performance Comparison

### Before (Traditional Rails)

```
spec/models/user_spec.rb                  # 50 tests × 200ms = 10s
spec/requests/sessions_spec.rb            # 20 tests × 300ms = 6s
                                          ─────────────────────
                                          Total: 16s for 70 tests
```

### After (Hanami-Compatible)

```
spec/domain/entities/user_spec.rb         # 40 tests × 2ms = 0.08s
spec/application/commands/.../auth_spec.rb # 10 tests × 50ms = 0.5s
spec/infrastructure/.../user_repo_spec.rb  # 10 tests × 50ms = 0.5s
spec/web/controllers/sessions_spec.rb     # 10 tests × 100ms = 1s
                                          ─────────────────────
                                          Total: 2.08s for 70 tests
```

**Speed Improvement**: 16s → 2.08s (8x faster!)

## Common Mistakes

### Mistake 1: Using Factories in Domain Tests

```ruby
# ❌ Bad
RSpec.describe Domain::Entities::User do
  it 'checks admin' do
    user = build(:user, :admin)  # Factory = database concern
    expect(user.admin?).to be true
  end
end

# ✅ Good
RSpec.describe Domain::Entities::User do
  it 'checks admin' do
    user = described_class.new(admin: true)  # Pure Ruby
    expect(user.admin?).to be true
  end
end
```

### Mistake 2: Testing Infrastructure in Domain

```ruby
# ❌ Bad - Domain test with database
RSpec.describe Domain::Entities::User do
  it 'saves to database' do
    user = described_class.new(...)
    expect { user.save }.to change(User, :count)
  end
end

# ✅ Good - Separate concerns
# Domain: Business logic only
# Infrastructure: Persistence only
```

### Mistake 3: Not Using Result Objects

```ruby
# ❌ Bad - Old Rails style
result = command.call(params)
expect(result).to be_a(Domain::Entities::User)

# ✅ Good - dry-monads Result
result = command.call(params)
expect(result).to be_success
expect(result.value!).to be_a(Domain::Entities::User)
```

## Summary

### Key Takeaways

1. **Organize by layer** - Domain, Application, Infrastructure, Web
2. **Domain tests = NO database** - 90% of tests should be fast
3. **Use Result objects** - `Success()` and `Failure()` everywhere
4. **Test Records, not Entities** - Factories create Records
5. **Separate concerns** - Each layer tests its own responsibility

### Migration Priority

1. ✅ **Start with domain tests** (easy, fast wins)
2. ✅ **Add application tests** (use case coverage)
3. ✅ **Update web tests** (integration coverage)
4. ✅ **Add infrastructure tests** (repository coverage)

### Expected Results

- ✅ Test suite 5-10x faster
- ✅ 90% of tests run in milliseconds
- ✅ Clear separation of concerns
- ✅ Easy to find and maintain tests
- ✅ Better test coverage (different layers)

---

**Document Version**: 1.0  
**Created**: 2024  
**Status**: Active Migration Guide