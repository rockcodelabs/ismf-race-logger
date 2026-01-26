# Implementation Plan: Rails 8.1 Fresh Setup with Docker on Raspberry Pi 5

## Feature: ISMF Race Logger - Fresh Rails 8.1 Application Setup

### Requirements Summary

- Create a fresh Rails 8.1 application for the ISMF Race Logger system
- Docker-based development and production environment (matching kw-app patterns)
- Deployment target: Raspberry Pi 5 (16GB RAM, 256GB NVMe)
- PostgreSQL database, Redis for caching/jobs
- Implement the domain models from architecture-overview.md
- Authentication system with magic links
- Authorization with Pundit
- **Field of Play (FOP) first UI** - optimized for 7" display, iPad, desktop, phone
- Domain via Cloudflare (matching kw-app pattern)
- ISMF branding matching https://ismf-ski.com/

### Technical Approach

**Key Design Decisions:**
- **Rails 8.1**: Latest stable version with built-in authentication generator
- **Docker Compose**: Multi-container setup for dev/prod parity (matching kw-app structure)
- **Kamal 2**: Deployment to Pi5 (ARM64 architecture) with staging/production destinations
- **PostgreSQL 16**: Primary database (upgraded from kw-app's 10.3)
- **Redis 7**: For Action Cable and caching
- **Solid Queue**: Built-in Rails 8 background job processor (alternative to Sidekiq)
- **TailwindCSS + Hotwire**: Modern frontend stack with responsive-first design
- **ARM64 Builds**: Pi5 native architecture
- **Bitwarden Secrets Manager**: Secret management (matching kw-app pattern)
- **chruby**: Local Ruby version management
- **Ansible**: Server provisioning (matching kw-app pattern)
- **Cloudflare**: DNS and SSL management

### Server Specs

| Component | Specification |
|-----------|---------------|
| Device | Raspberry Pi 5 |
| RAM | 16GB |
| Storage | 256GB NVMe SSD |
| Hostname | `pi5main.local` (shared with kw-app staging) |
| Architecture | ARM64 |
| OS | Ubuntu Server 24.04 LTS (64-bit) or Raspberry Pi OS |

### ISMF Brand Guidelines

Based on https://ismf-ski.com/:

| Element | Value |
|---------|-------|
| **Primary Color** | `#1a1a2e` (Dark Navy/Black) |
| **Accent Color** | `#e94560` (ISMF Red/Coral) |
| **Secondary** | `#0f3460` (Deep Blue) |
| **Background** | `#ffffff` (White) |
| **Text Primary** | `#1a1a2e` (Dark) |
| **Text Light** | `#6b7280` (Gray) |
| **Font Family** | Poppins (Google Fonts) |
| **Logo** | ISMF mountain/ski icon |

---

## Implementation Plan

### Phase 0: Prerequisites & Environment Setup

#### Task 0.1: Development Machine Setup (chruby)
- **Owner**: Developer
- **Details**:
  - Ruby 3.3.x via chruby + ruby-install
  - Rails 8.1.x gem
  - Docker Desktop (for local development)
- **Commands**:
  ```bash
  # Install Ruby 3.3.6 using ruby-install
  ruby-install ruby 3.3.6
  
  # Add to ~/.zshrc or ~/.bashrc
  echo "chruby ruby-3.3.6" >> ~/.zshrc
  source ~/.zshrc
  
  # Create .ruby-version in project
  echo "ruby-3.3.6" > .ruby-version
  
  # Install Rails 8.1
  gem install rails -v '~> 8.1'
  
  # Verify
  ruby -v   # 3.3.6
  rails -v  # 8.1.x
  ```
- **Dependencies**: None

#### Task 0.2: Verify Pi5 Server (Already Running kw-app)
- **Owner**: DevOps/User
- **Details**:
  Pi5 already running with Docker for kw-app staging. Verify resources:
  ```bash
  ssh rege@pi5main.local
  
  # Check Docker
  docker --version  # Should be 24+
  docker ps         # Should show kw-app containers
  
  # Check available resources
  free -h           # 16GB RAM
  df -h             # 256GB NVMe
  
  # Check network setup
  cat /etc/hosts    # Verify hostname configuration
  ```
- **Network Considerations**:
  - kw-app staging uses ports: 3000 (web), 5433 (postgres), 6381 (redis)
  - ismf-race-logger will use different ports to avoid conflicts
- **Dependencies**: None

---

### Phase 1: Rails Application Initialization

#### Task 1.1: Generate Fresh Rails 8.1 Application
- **Owner**: Developer
- **Details**:
  - Use PostgreSQL as database
  - Include Propshaft (default asset pipeline in Rails 8)
  - Include TailwindCSS
  - Skip test (we'll add RSpec later)
- **Commands**:
  ```bash
  cd ~/code
  rails new ismf-race-logger \
    --database=postgresql \
    --css=tailwind \
    --skip-test \
    --skip-system-test \
    --asset-pipeline=propshaft
  
  cd ismf-race-logger
  
  # Create .ruby-version for chruby
  echo "ruby-3.3.6" > .ruby-version
  ```
- **Dependencies**: Task 0.1

#### Task 1.2: Configure Gemfile for Production Stack
- **Owner**: Developer
- **File**: `Gemfile`
- **Content**:
  ```ruby
  source 'https://rubygems.org'
  ruby '3.3.6'
  
  # Core Rails
  gem 'rails', '~> 8.1'
  gem 'pg', '~> 1.5'
  gem 'puma', '>= 6.0'
  gem 'bootsnap', require: false
  
  # Asset Pipeline
  gem 'propshaft'
  gem 'tailwindcss-rails'
  
  # Hotwire
  gem 'turbo-rails'
  gem 'stimulus-rails'
  
  # API
  gem 'jbuilder'
  
  # Authentication
  gem 'bcrypt', '~> 3.1'
  
  # Rails 8 Solid Stack
  gem 'solid_queue'
  gem 'solid_cache'
  gem 'solid_cable'
  
  # Authorization
  gem 'pundit', '~> 2.3'
  
  # dry-rb (matching kw-app patterns)
  gem 'dry-monads', '~> 1.6'
  gem 'dry-validation', '~> 1.10'
  gem 'dry-schema', '~> 1.13'
  gem 'dry-types', '~> 1.7'
  gem 'dry-struct'
  
  # Image processing for Active Storage
  gem 'image_processing', '~> 1.12'
  
  # Deployment
  gem 'thruster', require: false
  gem 'kamal', '~> 2.10', require: false, group: [:tools]
  
  group :development, :test do
    gem 'rspec-rails', '~> 7.1'
    gem 'factory_bot_rails', '~> 6.4'
    gem 'faker', '~> 3.5'
    gem 'shoulda-matchers', '~> 6.4'
    gem 'timecop', '~> 0.9'
    gem 'debug'
    gem 'byebug'
  end
  
  group :development do
    gem 'web-console'
    gem 'rack-mini-profiler'
    gem 'spring'
    gem 'listen'
    gem 'annotate'
    gem 'brakeman', require: false
  end
  
  group :test do
    gem 'database_cleaner-active_record', '~> 2.2'
    gem 'simplecov', '~> 0.22', require: false
    gem 'capybara'
    gem 'selenium-webdriver'
    gem 'webmock', '~> 3.24'
  end
  ```
- **Commands**:
  ```bash
  bundle install
  ```
- **Dependencies**: Task 1.1

#### Task 1.3: Initialize Git Repository
- **Owner**: Developer
- **Commands**:
  ```bash
  git init
  git add .
  git commit -m "Initial Rails 8.1 application"
  ```
- **Dependencies**: Task 1.2

---

### Phase 2: Field of Play (FOP) UI Foundation

> **PRIORITY**: This phase is critical - the app is designed for field use on various devices.

#### Task 2.1: Configure TailwindCSS with ISMF Branding
- **Owner**: Developer
- **File**: `config/tailwind.config.js`
- **Content**:
  ```javascript
  const defaultTheme = require('tailwindcss/defaultTheme')

  module.exports = {
    content: [
      './public/*.html',
      './app/helpers/**/*.rb',
      './app/javascript/**/*.js',
      './app/views/**/*.{erb,haml,html,slim}',
      './app/components/**/*.{erb,rb}'
    ],
    theme: {
      extend: {
        fontFamily: {
          sans: ['Poppins', ...defaultTheme.fontFamily.sans],
        },
        colors: {
          // ISMF Brand Colors
          'ismf': {
            'navy': '#1a1a2e',
            'red': '#e94560',
            'blue': '#0f3460',
            'gray': '#6b7280',
          },
          // Semantic colors for FOP
          'fop': {
            'success': '#10b981',
            'warning': '#f59e0b',
            'danger': '#ef4444',
            'info': '#3b82f6',
          }
        },
        // Responsive breakpoints optimized for FOP devices
        screens: {
          'fop-7': '600px',    // 7" display
          'tablet': '768px',   // iPad mini
          'ipad': '1024px',    // iPad
          'desktop': '1280px', // Desktop
        },
        // Touch-friendly sizing
        spacing: {
          'touch': '44px',     // Minimum touch target
          'touch-lg': '56px',  // Large touch target
        }
      },
    },
    plugins: [
      require('@tailwindcss/forms'),
      require('@tailwindcss/typography'),
    ],
  }
  ```
- **Dependencies**: Task 1.2

#### Task 2.2: Create FOP Base Layout
- **Owner**: Developer
- **File**: `app/views/layouts/fop.html.erb`
- **Content**:
  ```erb
  <!DOCTYPE html>
  <html lang="en" class="h-full">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
      <meta name="apple-mobile-web-app-capable" content="yes">
      <meta name="mobile-web-app-capable" content="yes">
      <title><%= content_for(:title) || "ISMF Race Logger" %></title>
      
      <!-- ISMF Favicon -->
      <link rel="icon" type="image/png" href="/favicon.png">
      
      <!-- Poppins Font -->
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">
      
      <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
      <%= javascript_importmap_tags %>
    </head>
    
    <body class="h-full bg-gray-50 font-sans antialiased">
      <!-- FOP Header - Compact for small screens -->
      <header class="bg-ismf-navy text-white sticky top-0 z-50 safe-area-inset">
        <div class="flex items-center justify-between px-3 py-2 fop-7:px-4">
          <%= link_to root_path, class: "flex items-center gap-2" do %>
            <%= image_tag "ismf-logo-white.svg", class: "h-8 w-auto", alt: "ISMF" %>
            <span class="font-semibold text-sm hidden fop-7:inline">Race Logger</span>
          <% end %>
          
          <div class="flex items-center gap-2">
            <%= yield :header_actions %>
            
            <% if current_user %>
              <button type="button" 
                      class="p-2 rounded-lg hover:bg-white/10 touch-target"
                      data-controller="dropdown">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
              </button>
            <% end %>
          </div>
        </div>
        
        <!-- Race Context Bar (when in active race) -->
        <%= yield :race_context %>
      </header>
      
      <!-- Main Content -->
      <main class="flex-1 overflow-auto">
        <%= yield %>
      </main>
      
      <!-- FOP Bottom Navigation (mobile/tablet) -->
      <nav class="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 
                  safe-area-inset desktop:hidden z-40">
        <div class="flex justify-around py-2">
          <%= render "shared/fop_nav_item", icon: "home", label: "Dashboard", path: root_path %>
          <%= render "shared/fop_nav_item", icon: "flag", label: "Races", path: races_path %>
          <%= render "shared/fop_nav_item", icon: "alert", label: "Incidents", path: incidents_path %>
          <%= render "shared/fop_nav_item", icon: "clipboard", label: "Reports", path: reports_path %>
        </div>
      </nav>
      
      <!-- Toast Notifications -->
      <div id="notifications" 
           class="fixed top-16 right-4 z-50 space-y-2"
           data-controller="notifications">
      </div>
    </body>
  </html>
  ```
- **Dependencies**: Task 2.1

#### Task 2.3: Create FOP Component Library
- **Owner**: Developer
- **Files to create**:
  - `app/components/fop/button_component.rb`
  - `app/components/fop/card_component.rb`
  - `app/components/fop/status_badge_component.rb`
  - `app/components/fop/location_selector_component.rb`
  - `app/components/fop/incident_card_component.rb`
- **Example** (`app/components/fop/button_component.rb`):
  ```ruby
  # frozen_string_literal: true
  
  module Fop
    class ButtonComponent < ViewComponent::Base
      VARIANTS = {
        primary: "bg-ismf-red hover:bg-ismf-red/90 text-white",
        secondary: "bg-ismf-navy hover:bg-ismf-navy/90 text-white",
        outline: "border-2 border-ismf-navy text-ismf-navy hover:bg-ismf-navy/5",
        danger: "bg-fop-danger hover:bg-fop-danger/90 text-white",
        success: "bg-fop-success hover:bg-fop-success/90 text-white",
      }.freeze
      
      SIZES = {
        sm: "px-3 py-2 text-sm min-h-[36px]",
        md: "px-4 py-3 text-base min-h-[44px]",  # Default touch-friendly
        lg: "px-6 py-4 text-lg min-h-[56px]",    # Large touch target
      }.freeze
      
      def initialize(variant: :primary, size: :md, full_width: false, **options)
        @variant = variant
        @size = size
        @full_width = full_width
        @options = options
      end
      
      def call
        content_tag :button, content, class: button_classes, **@options
      end
      
      private
      
      def button_classes
        [
          "inline-flex items-center justify-center gap-2",
          "font-semibold rounded-lg",
          "transition-colors duration-150",
          "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-ismf-red",
          "disabled:opacity-50 disabled:cursor-not-allowed",
          VARIANTS[@variant],
          SIZES[@size],
          @full_width ? "w-full" : nil,
        ].compact.join(" ")
      end
    end
  end
  ```
- **Dependencies**: Task 2.2

#### Task 2.4: Create Responsive Incident Entry Form
- **Owner**: Developer
- **File**: `app/views/incidents/_form.html.erb`
- **Details**:
  - Large touch targets for field use
  - Quick-select buttons for common incident types
  - Location selector with race map integration
  - Camera/video upload with progress indicator
  - Works offline with service worker sync
- **Dependencies**: Task 2.3

#### Task 2.5: Add PWA Support for Field Use
- **Owner**: Developer
- **Files**:
  - `public/manifest.json`
  - `app/javascript/service_worker.js`
- **Content** (`public/manifest.json`):
  ```json
  {
    "name": "ISMF Race Logger",
    "short_name": "Race Logger",
    "description": "Field of Play incident logging for ski mountaineering races",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#1a1a2e",
    "theme_color": "#1a1a2e",
    "orientation": "any",
    "icons": [
      {
        "src": "/icons/icon-192.png",
        "sizes": "192x192",
        "type": "image/png"
      },
      {
        "src": "/icons/icon-512.png",
        "sizes": "512x512",
        "type": "image/png"
      }
    ]
  }
  ```
- **Dependencies**: Task 2.2

---

### Phase 3: Docker Development Environment

#### Task 3.1: Create Development Dockerfile
- **Owner**: Developer
- **File**: `Dockerfile`
- **Content** (matching kw-app pattern):
  ```dockerfile
  ARG RUBY_VERSION=3.3.6
  FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
  
  # Rails app lives here
  WORKDIR /rails
  
  # Install base packages
  RUN apt-get update -qq && \
      apt-get install --no-install-recommends -y \
        curl \
        libjemalloc2 \
        libpq-dev \
        postgresql-client \
        build-essential \
        bash \
        bash-completion \
        git \
        pkg-config \
        tzdata \
        imagemagick \
        libvips \
        nodejs \
        npm && \
      rm -rf /var/lib/apt/lists /var/cache/apt/archives
  
  # Set development environment
  ENV RAILS_ENV="development" \
      BUNDLE_WITHOUT=""
  
  # Install application gems
  COPY Gemfile Gemfile.lock ./
  RUN bundle install
  
  # Copy application code
  COPY . .
  
  # Precompile bootsnap code for faster boot times
  RUN bundle exec bootsnap precompile app/ lib/
  
  # Final stage for app image
  FROM base
  
  # Run and own only the runtime files as a non-root user for security
  RUN groupadd --system --gid 1000 rails && \
      useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
      chown -R rails:rails db log tmp && \
      chown -R rails:rails /usr/local/bundle
  
  USER 1000:1000
  
  # Entrypoint checks bundle and prepares the database.
  ENTRYPOINT ["./bin/bundle-check", "./bin/docker-entrypoint"]
  
  # Start server via Thruster by default
  EXPOSE 3000
  CMD ["./bin/thrust", "./bin/rails", "server"]
  ```
- **Dependencies**: Task 1.2

#### Task 3.2: Create bin/bundle-check Script
- **Owner**: Developer
- **File**: `bin/bundle-check`
- **Content**:
  ```bash
  #!/bin/bash -e
  
  # Check if bundle is up to date, install if needed
  if [ -f "Gemfile" ]; then
    echo "Checking bundle..."
    bundle check || bundle install --no-cache
  fi
  
  exec "${@}"
  ```
- **Commands**:
  ```bash
  chmod +x bin/bundle-check
  ```
- **Dependencies**: Task 3.1

#### Task 3.3: Create bin/docker-entrypoint Script
- **Owner**: Developer
- **File**: `bin/docker-entrypoint`
- **Content**:
  ```bash
  #!/bin/bash -e
  
  # Enable jemalloc for reduced memory usage and latency.
  if [ -z "${LD_PRELOAD+x}" ]; then
      LD_PRELOAD=$(find /usr/lib -name libjemalloc.so.2 -print -quit)
      export LD_PRELOAD
  fi
  
  # If running the rails server then create or migrate existing database
  if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
    echo "RAILS_ENV=${RAILS_ENV}"
    echo "DB_HOST=${DB_HOST}"
  
    # Remove stale PID file if it exists
    rm -f /rails/tmp/pids/server.pid
  
    ./bin/rails db:prepare
  fi
  
  exec "${@}"
  ```
- **Commands**:
  ```bash
  chmod +x bin/docker-entrypoint
  ```
- **Dependencies**: Task 3.2

#### Task 3.4: Create Docker Compose for Development
- **Owner**: Developer
- **File**: `docker-compose.yml`
- **Content** (following kw-app conventions, different ports):
  ```yaml
  services:
    app:
      command: ./bin/thrust ./bin/rails server -p 3003 -b 0.0.0.0
      build: .
      environment:
        - DB_HOST=postgres
        - REDIS_URL=redis://redis:6379/0
        - RAILS_ENV=development
      volumes:
        - .:/rails
        - ismf-bundle:/usr/local/bundle
        - ismf-tmp:/rails/tmp
      ports:
        - "3003:3003"
      depends_on:
        - postgres
        - redis
        - mailcatcher
      tty: true
      stdin_open: true
      networks:
        - ismf-network

    postgres:
      container_name: ismf-postgres
      image: 'postgres:16-alpine'
      volumes:
        - ismf-postgres:/var/lib/postgresql/data
      environment:
        - POSTGRES_USER=dev-user
        - POSTGRES_PASSWORD=dev-password
        - POSTGRES_DB=ismf_race_logger_development
      ports:
        - "5434:5432"
      healthcheck:
        test: ["CMD-SHELL", "pg_isready -U dev-user"]
        interval: 5s
        timeout: 5s
        retries: 5
      networks:
        - ismf-network

    redis:
      container_name: ismf-redis
      image: 'redis:7-alpine'
      ports:
        - '6382:6379'
      volumes:
        - ismf-redis-data:/data
      command: redis-server --appendonly yes
      networks:
        - ismf-network

    solid_queue:
      container_name: ismf-solid-queue
      build: .
      command: ./bin/rails solid_queue:start
      volumes:
        - .:/rails
        - ismf-bundle:/usr/local/bundle
        - ismf-tmp:/rails/tmp
      depends_on:
        postgres:
          condition: service_healthy
      environment:
        - DB_HOST=postgres
        - REDIS_URL=redis://redis:6379/0
        - RAILS_ENV=development
      networks:
        - ismf-network

    mailcatcher:
      image: schickling/mailcatcher
      ports:
        - "1026:1025"
        - "1081:1080"
      networks:
        - ismf-network

  volumes:
    ismf-redis-data:
    ismf-postgres:
    ismf-bundle:
    ismf-tmp:

  networks:
    ismf-network:
      name: ismf-network
  ```
- **Port Mapping** (avoiding kw-app conflicts):
  | Service | ismf-race-logger | kw-app |
  |---------|------------------|--------|
  | Web | 3003 | 3002 |
  | PostgreSQL | 5434 | 5433 |
  | Redis | 6382 | 6380 |
  | MailCatcher Web | 1081 | 1080 |
  | MailCatcher SMTP | 1026 | 1025 |
- **Dependencies**: Task 3.3

#### Task 3.5: Configure database.yml for Docker
- **Owner**: Developer
- **File**: `config/database.yml`
- **Content**:
  ```yaml
  default: &default
    adapter: postgresql
    encoding: unicode
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
    host: <%= ENV.fetch("DB_HOST") { "localhost" } %>
    port: <%= ENV.fetch("DB_PORT") { 5432 } %>
    username: <%= ENV.fetch("POSTGRES_USER") { "dev-user" } %>
    password: <%= ENV.fetch("POSTGRES_PASSWORD") { "dev-password" } %>

  development:
    <<: *default
    database: ismf_race_logger_development

  test:
    <<: *default
    database: ismf_race_logger_test

  staging:
    <<: *default
    database: ismf_race_logger_staging

  production:
    <<: *default
    database: ismf_race_logger_production
  ```
- **Dependencies**: Task 3.4

#### Task 3.6: Create bin/dev-setup Script
- **Owner**: Developer
- **File**: `bin/dev-setup`
- **Content**:
  ```bash
  #!/bin/bash
  set -e

  echo "🚀 Setting up ISMF Race Logger Development Environment..."

  # Build containers
  echo "📦 Building Docker containers..."
  docker compose build

  # Start services
  echo "🗄️ Starting database and Redis..."
  docker compose up -d postgres redis mailcatcher
  sleep 5

  # Create databases
  echo "📊 Creating databases..."
  docker compose exec -T postgres psql -U dev-user -c "CREATE DATABASE ismf_race_logger_development;" postgres 2>/dev/null || true
  docker compose exec -T postgres psql -U dev-user -c "CREATE DATABASE ismf_race_logger_test;" postgres 2>/dev/null || true

  # Migrate and seed
  echo "🔄 Running migrations..."
  docker compose run --rm -T app bundle exec rails db:migrate db:seed

  # Start all services
  echo "🎯 Starting application..."
  docker compose up -d

  echo ""
  echo "✅ Setup complete!"
  echo ""
  echo "📍 Local services:"
  echo "   App:         http://localhost:3001"
  echo "   MailCatcher: http://localhost:1081"
  echo ""
  echo "📝 Useful commands:"
  echo "   docker compose logs -f app    # View logs"
  echo "   docker compose exec app bash  # Shell access"
  echo "   docker compose down           # Stop all services"
  ```
- **Commands**:
  ```bash
  chmod +x bin/dev-setup
  ```
- **Dependencies**: Task 3.5

#### Task 3.7: Verify Docker Development Setup
- **Owner**: Developer
- **Commands**:
  ```bash
  bin/dev-setup
  # Visit http://localhost:3001
  ```
- **Dependencies**: Task 3.6

---

### Phase 4: RSpec & Testing Setup

#### Task 4.1: Install and Configure RSpec
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails generate rspec:install
  ```
- **File**: `spec/rails_helper.rb` additions:
  ```ruby
  require 'spec_helper'
  ENV['RAILS_ENV'] ||= 'test'
  require_relative '../config/environment'
  abort("The Rails environment is running in production mode!") if Rails.env.production?
  require 'rspec/rails'

  Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

  RSpec.configure do |config|
    config.fixture_paths = [Rails.root.join('spec/fixtures')]
    config.use_transactional_fixtures = true
    config.infer_spec_type_from_file_location!
    config.filter_rails_from_backtrace!
    
    # FactoryBot
    config.include FactoryBot::Syntax::Methods
  end

  # Shoulda Matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
  ```
- **Dependencies**: Task 3.7

#### Task 4.2: Create Support Files
- **Owner**: Developer
- **File**: `spec/support/factory_bot.rb`:
  ```ruby
  RSpec.configure do |config|
    config.include FactoryBot::Syntax::Methods
  end
  ```
- **File**: `spec/support/pundit.rb`:
  ```ruby
  require 'pundit/rspec'
  ```
- **File**: `spec/support/database_cleaner.rb`:
  ```ruby
  RSpec.configure do |config|
    config.before(:suite) do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
  ```
- **Dependencies**: Task 4.1

---

### Phase 5: Authentication System (Rails 8.1 Native)

#### Task 5.1: Generate Rails 8.1 Authentication
- **Owner**: Developer
- **Details**:
  Rails 8.1 includes a built-in authentication generator
- **Commands**:
  ```bash
  docker compose exec app bin/rails generate authentication
  docker compose exec app bin/rails db:migrate
  ```
- **Generated Files**:
  - `app/models/user.rb`
  - `app/models/session.rb`
  - `app/controllers/sessions_controller.rb`
  - `app/controllers/concerns/authentication.rb`
  - Migrations for users and sessions tables
- **Dependencies**: Task 4.2

#### Task 5.2: Extend User Model with Domain Fields
- **Owner**: Developer
- **Migration**:
  ```bash
  docker compose exec app bin/rails generate migration AddFieldsToUsers \
    name:string \
    country:string \
    ref_level:integer \
    role:references
  ```
- **Model Updates** (`app/models/user.rb`):
  ```ruby
  class User < ApplicationRecord
    has_secure_password
    has_many :sessions, dependent: :destroy
    has_many :magic_links, dependent: :destroy
    has_many :reports
    belongs_to :role

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :name, presence: true

    normalizes :email, with: ->(email) { email.strip.downcase }

    enum :ref_level, { national: 0, international: 1 }, prefix: true

    scope :referees, -> { joins(:role).where(roles: { name: %w[national_referee international_referee] }) }
    scope :var_operators, -> { joins(:role).where(roles: { name: 'var_operator' }) }

    # Role check methods
    %w[var_operator national_referee international_referee jury_president referee_manager broadcast_viewer].each do |role_name|
      define_method("#{role_name}?") { role&.name == role_name }
    end

    def referee?
      national_referee? || international_referee?
    end

    def generate_magic_link!
      magic_links.create!
    end
  end
  ```
- **Dependencies**: Task 5.1

#### Task 5.3: Create MagicLink Model
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails generate model MagicLink \
    user:references \
    token:string:uniq \
    expires_at:datetime \
    used_at:datetime
  ```
- **Model** (`app/models/magic_link.rb`):
  ```ruby
  class MagicLink < ApplicationRecord
    belongs_to :user

    validates :token, presence: true, uniqueness: true
    validates :expires_at, presence: true

    before_validation :generate_token, on: :create
    before_validation :set_expiry, on: :create

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
    end

    private

    def generate_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end

    def set_expiry
      self.expires_at ||= 15.minutes.from_now
    end
  end
  ```
- **Dependencies**: Task 5.2

#### Task 5.4: Write Authentication Tests
- **Owner**: Developer (via @rspec)
- **Files**:
  - `spec/models/user_spec.rb`
  - `spec/models/magic_link_spec.rb`
  - `spec/requests/sessions_spec.rb`
- **Dependencies**: Task 5.3

---

### Phase 6: Authorization with Pundit

#### Task 6.1: Install and Configure Pundit
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails generate pundit:install
  ```
- **File**: `app/controllers/application_controller.rb`:
  ```ruby
  class ApplicationController < ActionController::Base
    include Authentication
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    private

    def user_not_authorized
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, alert: "You are not authorized to perform this action.") }
        format.json { render json: { error: "Not authorized" }, status: :forbidden }
      end
    end
  end
  ```
- **Dependencies**: Task 5.4

#### Task 6.2: Create Role Model
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails generate model Role name:string:uniq
  ```
- **Model** (`app/models/role.rb`):
  ```ruby
  class Role < ApplicationRecord
    has_many :users

    NAMES = %w[
      var_operator
      national_referee
      international_referee
      jury_president
      referee_manager
      broadcast_viewer
    ].freeze

    validates :name, presence: true, uniqueness: true, inclusion: { in: NAMES }
  end
  ```
- **Seed Data** (`db/seeds.rb`):
  ```ruby
  puts "Creating roles..."
  Role::NAMES.each { |name| Role.find_or_create_by!(name: name) }
  puts "Created #{Role.count} roles"
  ```
- **Dependencies**: Task 6.1

#### Task 6.3: Create Domain Policies
- **Owner**: Developer
- **Files to create** (per architecture-overview.md):
  - `app/policies/application_policy.rb`
  - `app/policies/incident_policy.rb`
  - `app/policies/report_policy.rb`
  - `app/policies/race_policy.rb`
  - `app/policies/race_location_policy.rb`
  - `app/policies/competition_policy.rb`
  - `app/policies/race_type_policy.rb`
- **Dependencies**: Task 6.2

---

### Phase 7: Domain Models

#### Task 7.1: Create Core Competition Models
- **Owner**: Developer
- **Models to create in order** (per architecture-overview.md):
  1. `RaceType`
  2. `RaceTypeLocationTemplate`
  3. `CompetitionTemplate`
  4. `StageTemplate`
  5. `RaceTemplate`
  6. `CompetitionTemplateRaceType`
  7. `Competition`
  8. `Stage`
  9. `Race`
  10. `RaceLocation`
  11. `Rule`
  12. `Incident`
  13. `Report`
- **Example Commands**:
  ```bash
  # RaceType
  docker compose exec app bin/rails generate model RaceType \
    name:string

  # Competition
  docker compose exec app bin/rails generate model Competition \
    name:string \
    place:string \
    country:string \
    start_date:date \
    end_date:date \
    position:integer

  # Stage
  docker compose exec app bin/rails generate model Stage \
    competition:references \
    name:string \
    position:integer

  # Race
  docker compose exec app bin/rails generate model Race \
    stage:references \
    race_type:references \
    name:string \
    status:integer \
    scheduled_at:datetime

  # Continue for all models...
  ```
- **Dependencies**: Task 6.3

#### Task 7.2: Add Associations and Validations
- **Owner**: Developer
- **Details**: 
  Implement all associations as defined in architecture-overview.md
- **Dependencies**: Task 7.1

#### Task 7.3: Write Model Tests
- **Owner**: Developer (via @rspec)
- **Details**: Create specs for all models
- **Commands**:
  ```bash
  docker compose exec app bundle exec rspec spec/models
  ```
- **Dependencies**: Task 7.2

---

### Phase 8: Production Docker Setup

#### Task 8.1: Create Production Dockerfile
- **Owner**: Developer
- **File**: `Dockerfile.production`
- **Content** (matching kw-app pattern):
  ```dockerfile
  # syntax=docker/dockerfile:1
  # check=error=true

  ARG RUBY_VERSION=3.3.6
  FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

  WORKDIR /rails

  # Install base packages
  RUN apt-get update -qq && \
      apt-get install --no-install-recommends -y \
        curl \
        libjemalloc2 \
        libpq-dev \
        postgresql-client \
        build-essential \
        bash \
        git \
        pkg-config \
        tzdata \
        imagemagick \
        libvips \
        nodejs && \
      rm -rf /var/lib/apt/lists /var/cache/apt/archives

  # Set production environment
  ENV RAILS_ENV="production" \
      BUNDLE_DEPLOYMENT="1" \
      BUNDLE_PATH="/usr/local/bundle" \
      BUNDLE_WITHOUT="development:test"

  # Throw-away build stage to reduce size of final image
  FROM base AS build

  # Install application gems
  COPY Gemfile Gemfile.lock ./
  RUN bundle install && \
      rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
      bundle exec bootsnap precompile --gemfile

  # Copy application code
  COPY . .

  # Precompile bootsnap code for faster boot times
  RUN bundle exec bootsnap precompile app/ lib/

  # Precompiling assets for production without requiring secret RAILS_MASTER_KEY
  RUN SECRET_KEY_BASE=1 ./bin/rails assets:precompile

  # Final stage for app image
  FROM base

  # Copy built artifacts: gems, application
  COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
  COPY --from=build /rails /rails

  # Run and own only the runtime files as a non-root user for security
  RUN groupadd --system --gid 1000 rails && \
      useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
      chown -R rails:rails db log tmp
  USER 1000:1000

  # Entrypoint prepares the database.
  ENTRYPOINT ["/rails/bin/docker-entrypoint"]

  EXPOSE 3000
  CMD ["bundle", "exec", "thrust", "./bin/rails", "server"]
  ```
- **Dependencies**: Task 7.3

---

### Phase 9: Ansible Server Provisioning

#### Task 9.1: Create Ansible Directory Structure
- **Owner**: Developer
- **Structure**:
  ```
  ansible/
  ├── README.md
  ├── inventory/
  │   └── staging.ini
  ├── staging/
  │   ├── prepare-for-kamal.yml
  │   └── vars/
  │       └── server_config.yml
  ```
- **Dependencies**: Task 8.1

#### Task 9.2: Create Ansible Inventory
- **Owner**: Developer
- **File**: `ansible/inventory/staging.ini`
- **Content**:
  ```ini
  [staging_pi]
  pi5main.local ansible_user=rege

  [staging_pi:vars]
  ansible_python_interpreter=/usr/bin/python3
  ```
- **Dependencies**: Task 9.1

#### Task 9.3: Create Server Config Vars
- **Owner**: Developer
- **File**: `ansible/staging/vars/server_config.yml`
- **Content**:
  ```yaml
  staging_user: rege
  app_name: ismf-race-logger
  network_name: ismf-network
  postgres_port: 5435
  redis_port: 6383
  ```
- **Dependencies**: Task 9.1

#### Task 9.4: Create Kamal Preparation Playbook
- **Owner**: Developer
- **File**: `ansible/staging/prepare-for-kamal.yml`
- **Content**:
  ```yaml
  ---
  - name: Prepare Raspberry Pi for ISMF Race Logger Kamal Deployment
    hosts: staging_pi
    
    vars_files:
      - vars/server_config.yml
    
    vars:
      postgres_container: "ismf-staging-postgres"
      postgres_user: "staging_user"
    
    tasks:
      - name: Prompt for sudo password
        pause:
          prompt: "Enter sudo password for {{ staging_user }}"
          echo: no
        register: sudo_password_prompt
        
      - name: Set sudo password
        set_fact:
          ansible_become_pass: "{{ sudo_password_prompt.user_input }}"
        no_log: true
      
      - name: Update apt cache
        become: yes
        apt:
          update_cache: yes
          cache_valid_time: 3600
      
      - name: Install required system packages
        become: yes
        apt:
          name:
            - docker.io
            - curl
            - python3-pip
            - python3-docker
            - jq
          state: present
      
      - name: Add user to docker group
        become: yes
        user:
          name: "{{ staging_user }}"
          groups: docker
          append: yes
      
      - name: Enable and start Docker service
        become: yes
        systemd:
          name: docker
          enabled: yes
          state: started
      
      - name: Reset SSH connection to apply docker group
        meta: reset_connection
      
      - name: Create kamal directory
        become: yes
        become_user: "{{ staging_user }}"
        file:
          path: /home/{{ staging_user }}/.kamal
          state: directory
          mode: '0755'
      
      - name: Create ismf-network if not exists
        become: yes
        community.docker.docker_network:
          name: "{{ network_name }}"
          state: present
      
      - name: Prompt for Docker registry username
        pause:
          prompt: "Enter Docker Hub username"
        register: docker_username_prompt
        
      - name: Prompt for Docker registry password
        pause:
          prompt: "Enter Docker Hub password/token"
          echo: no
        register: docker_password_prompt
      
      - name: Login to Docker Hub
        shell: |
          echo "{{ docker_password_prompt.user_input }}" | docker login -u "{{ docker_username_prompt.user_input }}" --password-stdin
        args:
          executable: /bin/bash
        no_log: true
        register: docker_login_result
        failed_when: docker_login_result.rc != 0
      
      - name: Display preparation status
        debug:
          msg:
            - "✅ Server preparation complete for ISMF Race Logger!"
            - "   - Docker installed and running"
            - "   - User '{{ staging_user }}' added to docker group"
            - "   - Network '{{ network_name }}' created"
            - "   - Docker Hub login configured"
            - ""
            - "Next: Run 'kamal setup -d staging' from your dev machine"
  ```
- **Dependencies**: Task 9.3

#### Task 9.5: Create Ansible README
- **Owner**: Developer
- **File**: `ansible/README.md`
- **Content**:
  ```markdown
  # ISMF Race Logger - Server Provisioning

  Ansible playbooks for staging (Raspberry Pi 5) provisioning.

  ## Prerequisites

  - Bitwarden CLI (`brew install bitwarden-cli`)
  - Ansible (`brew install ansible`)
  - SSH access to pi5main.local
  - Docker Hub account

  ## Fresh Staging Setup (Raspberry Pi)

  ### 1. Unlock Bitwarden
  ```bash
  export BW_SESSION=$(bw unlock --raw)
  bw sync --session "$BW_SESSION"
  ```

  ### 2. Provision Server (One-Time)
  ```bash
  cd ~/code/ismf-race-logger

  ansible-playbook ansible/staging/prepare-for-kamal.yml \
    -i ansible/inventory/staging.ini \
    --extra-vars "ansible_python_interpreter=/usr/bin/python3"
  ```

  ### 3. Export Secrets
  ```bash
  export KAMAL_REGISTRY_USERNAME=$(bw get username "ismf-race-logger-docker-registry" --session "$BW_SESSION")
  export KAMAL_REGISTRY_PASSWORD=$(bw get password "ismf-race-logger-docker-registry" --session "$BW_SESSION")
  export RAILS_MASTER_KEY=$(bw get notes "ismf-race-logger-staging-master-key" --session "$BW_SESSION")
  export POSTGRES_PASSWORD=$(bw get password "ismf-race-logger-staging-database" --session "$BW_SESSION")
  export REDIS_PASSWORD=$(bw get password "ismf-race-logger-staging-redis" --session "$BW_SESSION")
  ```

  ### 4. Initial Deploy
  ```bash
  kamal setup -d staging
  ```

  ### 5. Initialize Database
  ```bash
  kamal app exec -d staging --reuse "bin/rails db:create"
  kamal app exec -d staging --reuse "bin/rails db:schema:load"
  kamal app exec -d staging --reuse "bin/rails db:seed"
  ```

  ### 6. Verify
  ```bash
  curl https://race-logger.ismf-ski.com/up  # or your domain
  ssh rege@pi5main.local "docker ps | grep ismf"
  ```
  ```
- **Dependencies**: Task 9.4

---

### Phase 10: Kamal Deployment Configuration

#### Task 10.1: Initialize Kamal
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app kamal init
  ```
- **Dependencies**: Task 9.5

#### Task 10.2: Configure Base Kamal Deploy
- **Owner**: Developer
- **File**: `config/deploy.yml`
- **Content**:
  ```yaml
  # Base Kamal configuration - shared across all environments

  service: ismf-race-logger
  image: regedarek/ismf-race-logger

  builder:
    dockerfile: Dockerfile.production
    arch: amd64

  registry:
    username:
      - KAMAL_REGISTRY_USERNAME
    password:
      - KAMAL_REGISTRY_PASSWORD

  # Keep only 3 containers on host
  retain_containers: 3

  env:
    clear:
      DB_HOST: ismf-postgres
      DB_PORT: 5432
    secret:
      - RAILS_MASTER_KEY

  proxy:
    app_port: 3000
    healthcheck:
      path: /up
      interval: 2
      timeout: 5

  servers:
    web:
      options:
        network: "ismf-network"
  ```
- **Dependencies**: Task 10.1

#### Task 10.3: Configure Production Deploy for Pi5
- **Owner**: Developer
- **File**: `config/deploy.staging.yml`
- **Content**:
  ```yaml
  # Staging-specific configuration for Raspberry Pi 5

  service: ismf-race-logger-staging

  builder:
    arch: arm64

  servers:
    web:
      hosts:
        - pi5main.local  # Production on Pi5

  deploy_timeout: 180

  proxy:
    ssl: true
    host: race-logger.ismf-ski.com
    healthcheck:
      path: /up
      interval: 2
      timeout: 5

  env:
    clear:
      RAILS_ENV: production
      RACK_ENV: production
      DB_HOST: ismf-postgres
      RAILS_SERVE_STATIC_FILES: true

  ssh:
    user: rege

  accessories:
    postgres:
      service: ismf-postgres
      image: postgres:16-alpine
      host: pi5main.local
      port: "5435:5432"
      options:
        network: "ismf-network"
      env:
        clear:
          POSTGRES_USER: ismf_user
          POSTGRES_DB: ismf_race_logger_production
        secret:
          - POSTGRES_PASSWORD
      directories:
        - ismf-data-staging:/var/lib/postgresql/data

    redis:
      service: ismf-redis
      image: redis:7-alpine
      host: pi5main.local
      port: "6383:6379"
      options:
        network: "ismf-network"
      env:
        secret:
          - REDIS_PASSWORD
      cmd: sh -c 'redis-server --requirepass "$$REDIS_PASSWORD" --appendonly yes --dir /data'
      directories:
        - ismf-redis-data-staging:/data

    solid_queue:
      service: ismf-solid-queue
      image: regedarek/ismf-race-logger
      host: pi5main.local
      options:
        network: "ismf-network"
      cmd: bundle exec rails solid_queue:start
      env:
        clear:
          RAILS_ENV: production
          DB_HOST: ismf-postgres
        secret:
          - RAILS_MASTER_KEY
          - POSTGRES_PASSWORD
  ```
- **Dependencies**: Task 10.2

#### Task 10.4: Create Kamal Secrets (Bitwarden Integration)
- **Owner**: Developer
- **File**: `.kamal/secrets`
- **Content** (matching kw-app pattern):
  ```bash
  #!/bin/bash
  # Kamal secrets - local development
  # Fetches secrets from Bitwarden Secrets Manager for local deployments

  # Check if running in CI/CD
  if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    export KAMAL_REGISTRY_USERNAME="${KAMAL_REGISTRY_USERNAME}"
    export KAMAL_REGISTRY_PASSWORD="${KAMAL_REGISTRY_PASSWORD}"
    export RAILS_MASTER_KEY="${RAILS_MASTER_KEY}"
    export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
    export REDIS_PASSWORD="${REDIS_PASSWORD}"
    exit 0
  fi

  # Local development - fetch from Bitwarden Secrets Manager
  if ! command -v bws &> /dev/null; then
    echo "❌ Bitwarden Secrets Manager CLI (bws) not installed" >&2
    echo "Install: brew install bitwarden/sm/bws" >&2
    exit 1
  fi

  if [ -z "$BWS_ACCESS_TOKEN" ]; then
    echo "❌ BWS_ACCESS_TOKEN not set" >&2
    echo "Get token from: https://vault.bitwarden.com → ismf-race-logger → Service Accounts" >&2
    echo "Then: export BWS_ACCESS_TOKEN=\"your-token\"" >&2
    exit 1
  fi

  # TODO: Replace with actual Bitwarden secret IDs after setup
  DESTINATION="${KAMAL_DESTINATION:-staging}"

  if [ "$DESTINATION" = "staging" ]; then
    # Staging secrets - update these IDs after creating in Bitwarden
    export KAMAL_REGISTRY_USERNAME=$(bws secret get YOUR_REGISTRY_USERNAME_ID --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null | jq -r '.value')
    export KAMAL_REGISTRY_PASSWORD=$(bws secret get YOUR_REGISTRY_PASSWORD_ID --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null | jq -r '.value')
    export RAILS_MASTER_KEY=$(bws secret get YOUR_RAILS_MASTER_KEY_ID --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null | jq -r '.value')
    export POSTGRES_PASSWORD=$(bws secret get YOUR_POSTGRES_PASSWORD_ID --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null | jq -r '.value')
    export REDIS_PASSWORD=$(bws secret get YOUR_REDIS_PASSWORD_ID --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null | jq -r '.value')
  fi

  # Verify all secrets were fetched
  if [[ -z "$KAMAL_REGISTRY_USERNAME" ]] || [[ -z "$KAMAL_REGISTRY_PASSWORD" ]] || [[ -z "$RAILS_MASTER_KEY" ]]; then
    echo "❌ Failed to fetch secrets from Bitwarden for $DESTINATION environment" >&2
    exit 1
  fi
  ```
- **Commands**:
  ```bash
  chmod +x .kamal/secrets
  echo ".kamal/secrets-local" >> .gitignore
  ```
- **Dependencies**: Task 10.3

---

### Phase 11: Cloudflare DNS & SSL Setup (Production)

#### Task 11.1: Configure Cloudflare DNS
- **Owner**: User
- **Details**:
  1. Log in to Cloudflare dashboard
  2. Select the `ismf-ski.com` domain (or your domain)
  3. Add DNS record:
     - Type: `A`
     - Name: `race-logger`
     - Content: Pi5 public IP (via Cloudflare Tunnel recommended)
     - Proxy status: Proxied (orange cloud)
- **Alternative - Cloudflare Tunnel** (recommended for home network):
  ```bash
  # On Pi5
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  sudo dpkg -i cloudflared.deb
  cloudflared tunnel login
  cloudflared tunnel create ismf-race-logger
  cloudflared tunnel route dns ismf-race-logger race-logger.ismf-ski.com
  ```
- **Dependencies**: Task 10.4

#### Task 11.2: Create Cloudflare Tunnel Config
- **Owner**: User
- **File on Pi5**: `~/.cloudflared/config.yml`
- **Content**:
  ```yaml
  tunnel: ismf-race-logger
  credentials-file: /home/rege/.cloudflared/<tunnel-id>.json

  ingress:
    - hostname: race-logger.ismf-ski.com
      service: http://localhost:3000
    - service: http_status:404
  ```
- **Commands**:
  ```bash
  # Start tunnel
  cloudflared tunnel run ismf-race-logger
  
  # Or install as service
  sudo cloudflared service install
  sudo systemctl start cloudflared
  ```
- **Dependencies**: Task 11.1

---

### Phase 12: Solid Stack Configuration

#### Task 12.1: Configure Solid Queue
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails solid_queue:install
  docker compose exec app bin/rails db:migrate
  ```
- **File**: `config/solid_queue.yml`:
  ```yaml
  default: &default
    dispatchers:
      - polling_interval: 1
        batch_size: 500
    workers:
      - queues: "*"
        threads: 3
        polling_interval: 0.1

  development:
    <<: *default

  staging:
    <<: *default
    workers:
      - queues: "*"
        threads: 5
        polling_interval: 0.1

  production:
    <<: *default
    workers:
      - queues: "*"
        threads: 5
        polling_interval: 0.1
  ```
- **Dependencies**: Task 8.1

#### Task 12.2: Configure Solid Cache
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails solid_cache:install
  docker compose exec app bin/rails db:migrate
  ```
- **File**: `config/environments/staging.rb` (add):
  ```ruby
  config.cache_store = :solid_cache_store
  ```
- **Dependencies**: Task 12.1

#### Task 12.3: Configure Solid Cable
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bin/rails solid_cable:install
  docker compose exec app bin/rails db:migrate
  ```
- **File**: `config/cable.yml`:
  ```yaml
  development:
    adapter: solid_cable
    polling_interval: 0.1

  test:
    adapter: test

  staging:
    adapter: solid_cable
    polling_interval: 0.1

  production:
    adapter: solid_cable
    polling_interval: 0.1
  ```
- **Dependencies**: Task 12.2

---

### Phase 13: Final Integration & Testing

#### Task 13.1: Run Full Test Suite
- **Owner**: Developer
- **Commands**:
  ```bash
  docker compose exec app bundle exec rspec
  ```
- **Dependencies**: All previous phases

#### Task 13.2: Production Smoke Test
- **Owner**: Developer
- **Checklist**:
  - [ ] Application loads at race-logger.ismf-ski.com (production)
  - [ ] ISMF branding displays correctly
  - [ ] User registration works
  - [ ] User login works
  - [ ] Magic link authentication works
  - [ ] Background jobs process (Solid Queue)
  - [ ] WebSocket connections work (Solid Cable)
  - [ ] Asset pipeline serves correctly
  - [ ] FOP layout works on mobile
  - [ ] FOP layout works on 7" display
  - [ ] FOP layout works on iPad
  - [ ] PWA install works
- **Commands**:
  ```bash
  # Check logs
  kamal app logs -d production
  
  # Check container health
  ssh rege@pi5main.local docker ps | grep ismf
  
  # Rails console
  kamal app exec -d production --reuse 'bin/rails console'
  ```
- **Dependencies**: Task 11.2

> **Note**: No staging environment - test thoroughly in development before deploying to production.

#### Task 13.3: Documentation
- **Owner**: Developer
- **Files to create/update**:
  - `README.md` - Project overview and quick start
  - `docs/DEPLOYMENT.md` - Deployment instructions
  - `docs/DEVELOPMENT.md` - Development setup guide
  - `docs/FOP_UI_GUIDE.md` - Field of Play UI guidelines
  - `CLAUDE.md` - AI assistant guidelines
- **Dependencies**: Task 13.2

---

### Phase 14: FOP Real-Time Performance & Report Grouping

> **Reference**: 
> - `docs/features/fop-realtime-performance.md` - Complete implementation details
> - `docs/architecture/report-incident-model.md` - Data model architecture (Report/Incident)

This phase implements real-time notifications for desktop devices and the report grouping workflow for incident management.

**Key Design Decisions:**
- **Reports are observations** - No status on reports, just data
- **Incidents are cases** - All status/decision logic lives here
- **1:1 auto-create** - Every report creates its own incident (referees don't think)
- **Two-level status** - Level 1: unofficial→official (lifecycle), Level 2: pending→penalty_applied/rejected/no_action (decision)
- **Merge = transfer reports** - Move reports from source incidents to target, delete empty incidents
- **Speed target**: < 100ms for report creation on FOP devices

#### Task 14.0: Speed-Optimized Report Creation
- **Owner**: Developer
- **Services**:
  - `app/services/reports/create.rb` - Creates report + incident in single transaction
  - `app/jobs/reports/broadcast_job.rb` - Background broadcast (non-blocking)
- **Performance Target**: < 100ms total response time
- **Details**:
  - 2 INSERTs per report (Incident + Report)
  - Minimal validations
  - Background job for Action Cable broadcast
  - JSON API response (no view rendering)
- **Dependencies**: Phase 7

#### Task 14.1: Configure Solid Cable for Real-Time
- **Owner**: Developer
- **Files**:
  - `config/cable.yml`
- **Details**: Configure Solid Cable with 100ms polling interval
- **Dependencies**: Phase 12

#### Task 14.2: Create Bib Number Quick Select (FOP Devices)
- **Owner**: Developer
- **Components**:
  - `app/javascript/controllers/bib_selector_controller.js`
  - `app/components/fop/bib_selector_component.rb`
- **Details**: 
  - Pre-load active bibs (8-200) as JSON
  - Client-side filtering (< 10ms for 200 bibs)
  - Touch-optimized grid (56px targets)
  - Recent bibs in localStorage
- **Dependencies**: Task 14.1

#### Task 14.3: Create Real-Time Channels (Desktop Only)
- **Owner**: Developer
- **Files**:
  - `app/channels/reports_channel.rb`
  - `app/channels/incidents_channel.rb`
  - `app/channels/application_cable/connection.rb`
  - `app/javascript/channels/reports_channel.js`
- **Details**: 
  - Race-scoped channels
  - Desktop devices subscribe to receive notifications
  - FOP devices do NOT subscribe (creation only)
- **Dependencies**: Task 14.2

#### Task 14.4: Add Broadcast Callbacks to Models
- **Owner**: Developer
- **Files**:
  - `app/models/report.rb` (add after_create_commit, after_update_commit)
  - `app/models/incident.rb` (add broadcast callbacks)
- **Details**: Broadcasts to desktop clients on create/update
- **Dependencies**: Task 14.3

#### Task 14.5: Create Report Selection Components (Desktop)
- **Owner**: Developer
- **Components**:
  - `app/javascript/controllers/report_selection_controller.js`
  - `app/components/fop/report_selection_component.rb`
  - `app/components/fop/floating_action_bar_component.rb`
- **Details**:
  - Multi-select checkboxes (56px touch targets)
  - Floating action bar appears when reports selected
  - "Group into Incident" button
- **Dependencies**: Task 14.4

#### Task 14.6: Create Incident Action Components (Desktop)
- **Owner**: Developer
- **Components**:
  - `app/components/fop/incident_actions_component.rb`
- **Details**:
  - Three touch-friendly buttons (56px height):
    - **Apply Penalty** (red, primary)
    - **Reject** (gray, secondary)
    - **No Action** (outline, tertiary)
  - Only shown for officialized incidents with pending status
- **Dependencies**: Task 14.5

#### Task 14.7: Create Incident Model with Two-Level Status
- **Owner**: Developer
- **Migration**: Create incidents table with integer enums
- **Model Update**: 
  ```ruby
  # Level 1: Lifecycle status
  enum :status, { unofficial: 0, official: 1 }
  
  # Level 2: Decision (only when official)
  enum :decision, {
    pending: 0,
    penalty_applied: 1,
    rejected: 2,
    no_action: 3
  }, prefix: :decision
  ```
- **Additional Fields**:
  - `officialized_at`, `officialized_by` (user_id)
  - `decided_at`, `decided_by` (user_id)
  - `reports_count` (counter cache)
- **Dependencies**: Task 14.6

#### Task 14.8: Create Incident Services
- **Owner**: Developer
- **Services**:
  - `app/services/incidents/merge.rb` - Merge incidents (move reports to target)
  - `app/services/incidents/officialize.rb` - Status: unofficial → official
  - `app/services/incidents/make_decision.rb` - Decision: penalty_applied/rejected/no_action
- **Details**: 
  - Uses dry-monads (Success/Failure)
  - Merge: transfer reports, delete empty incidents
  - Officialize: only Jury President can do this
  - Decision: only after officialized, records who/when
  - Broadcasts updates via IncidentsChannel
- **Dependencies**: Task 14.7

#### Task 14.9: Add Incident Routes and Controller
- **Owner**: Developer
- **Routes**:
  ```ruby
  resources :races do
    resources :incidents do
      member do
        patch :officialize    # Status: unofficial → official
        patch :apply_penalty  # Decision: penalty_applied
        patch :reject         # Decision: rejected
        patch :no_action      # Decision: no_action
      end
      collection do
        post :merge           # Merge multiple incidents
      end
    end
  end
  ```
- **Controller Actions**: create, apply, reject, no_action, officialize
- **Dependencies**: Task 14.8

#### Task 14.10: Create Notification Components (Desktop)
- **Owner**: Developer
- **Components**:
  - `app/components/fop/toast_component.rb`
  - `app/components/fop/new_reports_banner_component.rb`
  - `app/javascript/controllers/report_notifications_controller.js`
  - `app/javascript/controllers/toast_controller.js`
- **Details**:
  - Toast notifications for new reports
  - "X new reports" banner with refresh
  - Auto-dismiss after 5 seconds
- **Dependencies**: Task 14.9

#### Task 14.11: Write Real-Time & Grouping Tests
- **Owner**: Developer
- **Test Files**:
  - `spec/channels/reports_channel_spec.rb`
  - `spec/channels/incidents_channel_spec.rb`
  - `spec/services/incidents/group_reports_spec.rb`
  - `spec/services/incidents/update_status_spec.rb`
  - `spec/components/fop/report_selection_component_spec.rb`
  - `spec/components/fop/incident_actions_component_spec.rb`
  - `spec/system/report_grouping_spec.rb`
  - `spec/system/realtime_notifications_spec.rb`
- **Dependencies**: Task 14.10

#### Task 14.12: Performance Testing & Optimization
- **Owner**: Developer
- **Details**:
  - Add Bullet gem for N+1 detection
  - Create performance test suite
  - Verify bib filtering < 10ms for 200 bibs
  - Verify report list < 300ms for 100 reports
  - Verify broadcast delivery < 100ms
- **Dependencies**: Task 14.11

---

## Quick Reference

### Development Commands

```bash
# Start development environment
bin/dev-setup                           # First time setup
docker compose up -d                    # Start all services
docker compose logs -f app              # Tail logs

# Rails commands
docker compose exec app bash            # Shell access
docker compose exec app bin/rails c     # Rails console
docker compose exec app bundle exec rspec  # Run tests

# Database
docker compose exec app bin/rails db:migrate
docker compose exec app bin/rails db:seed
docker compose exec app bin/rails db:rollback
```

### Deployment Commands (Production)

```bash
# Provision server (first time)
ansible-playbook ansible/staging/prepare-for-kamal.yml \
  -i ansible/inventory/staging.ini

# Deploy
kamal deploy -d staging

# Rails console
kamal app exec -d staging --reuse 'bin/rails console'

# View logs
kamal app logs -d staging

# Database operations
kamal app exec -d staging --reuse 'bin/rails db:migrate'
kamal app exec -d staging --reuse 'bin/rails db:seed'

# Rollback
kamal rollback -d staging

# Check status
kamal app details -d staging
```

### Server Access (Pi5)

```bash
# SSH to Pi5
ssh rege@pi5main.local

# Check containers
docker ps | grep ismf

# Check resources
docker stats --no-stream

# View network
docker network inspect ismf-network
```

---

## Port Reference

| Service | Development | Production (Pi5) | kw-app (Pi5) |
|---------|-------------|------------------|--------------|
| Web App | 3003 | 3000 (via proxy) | 3000 |
| PostgreSQL | 5434 | 5435 | 5433 |
| Redis | 6382 | 6383 | 6381 |
| MailCatcher | 1081 | - | 1080 |

> **Note**: No staging environment. Only development (local Docker) and production (Pi5).

---

## Device Support Matrix

| Device | Screen Size | Priority | Role | Notes |
|--------|-------------|----------|------|-------|
| 7" Display | 600px | **HIGH** | FOP (Creation) | Field of Play primary device |
| iPad Mini | 768px | **HIGH** | FOP (Creation) | Referee tablets |
| iPad | 1024px | Medium | Desktop (Viewing) | Control room, report grouping |
| Desktop | 1280px+ | Medium | Desktop (Viewing) | Admin/reporting, incident actions |
| Phone | 375px+ | Medium | FOP (Creation) | Quick access |

### Device Role Separation

| Role | Capabilities | Receives Notifications |
|------|--------------|------------------------|
| **FOP (Creation)** | Create reports, select bibs, offline queue | ❌ No |
| **Desktop (Viewing)** | View reports, group into incidents, take action | ✅ Yes (Action Cable) |

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 0: Prerequisites | 1 hour | 1 hour |
| Phase 1: Rails Init | 30 min | 1.5 hours |
| **Phase 2: FOP UI Foundation** | **3 hours** | **4.5 hours** |
| Phase 3: Docker Dev | 1.5 hours | 6 hours |
| Phase 4: RSpec Setup | 30 min | 6.5 hours |
| Phase 5: Authentication | 2 hours | 8.5 hours |
| Phase 6: Authorization | 1.5 hours | 10 hours |
| Phase 7: Domain Models | 4-6 hours | 15 hours |
| Phase 8: Production Docker | 1 hour | 16 hours |
| Phase 9: Ansible Setup | 1 hour | 17 hours |
| Phase 10: Kamal Deploy | 2 hours | 19 hours |
| Phase 11: Cloudflare | 1 hour | 20 hours |
| Phase 12: Solid Stack | 1 hour | 21 hours |
| Phase 13: Testing & Docs | 2 hours | 23 hours |
| **Phase 14: Real-Time & Report Grouping** | **6 hours** | **29 hours** |

**Total Estimated Time: 4 days (29+ hours)**

---

## Risks & Considerations

### Field of Play Requirements
- **Risk**: Poor UX in field conditions (cold, gloves, bright sun)
- **Mitigation**: 
  - Large touch targets (min 44px)
  - High contrast ISMF colors
  - PWA for offline capability
  - Test on actual 7" displays

### Resource Sharing with kw-app
- **Risk**: Competing for Pi5 resources with kw-app staging
- **Mitigation**: 
  - 16GB RAM is sufficient for both apps
  - Set container memory limits
  - Use different port ranges
  - Monitor with `docker stats`

### Network Isolation
- **Risk**: Applications could potentially interfere
- **Mitigation**: 
  - Use separate Docker networks (`ismf-network` vs `kw-app-network`)
  - Different service container names

### Storage on NVMe
- **Advantage**: 256GB NVMe provides fast I/O for PostgreSQL
- **Recommendation**: Store database volumes on NVMe, not SD card

### Cloudflare Tunnel
- **Advantage**: No need to expose Pi5 directly to internet
- **Advantage**: Free SSL certificates
- **Advantage**: DDoS protection

---

*This plan follows the kw-app conventions and patterns for Docker development, Ansible provisioning, and Kamal deployment. FOP-first UI approach ensures field usability on all target devices.*