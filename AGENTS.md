# Agents

> Available agents for the ISMF Race Logger project.
> This document serves as a routing table for AI and human operators.

---

## Overview

Agents are specialized tools that solve specific problems. Each agent has a defined scope, required input, and expected output.

Use this document to:
- Understand what agents are available
- Know when to use (or not use) each agent
- Provide correct input format

**Important:** All commands shown in this document assume proper Ruby environment is active (Ruby 3.4.8 via chruby). See `.rules` section 6 for environment setup requirements.

---

## Agent Inventory

### 1. @feature

**Alias:** feature-bootstrapper

**Purpose:** Generate complete feature implementation following project architecture.

**When to Use:**
- Building new CRUD features
- Adding new models with full stack
- Creating admin pages for new resources

**When NOT to Use:**
- Small bug fixes
- Refactoring existing code
- Non-feature changes (config, deps, docs)

**Required Input:**
- Feature name
- Model/resource name
- Attributes (if new model)
- Views needed (index/show/new/edit)
- Authorization requirements

**Expected Output:**
- Migration, model, struct, repo, operation, controller, part, views, tests
- All files following project architecture

**Workflow:** See `docs/FEATURE_WORKFLOW.md`

---

### 2. @test

**Alias:** rails-test-runner

**Purpose:** Execute RSpec tests in Docker with correct environment.

**When to Use:**
- Running specific test files
- Running test suites by layer
- Debugging failing tests

**When NOT to Use:**
- You need to modify test files (use editor)
- Running non-test commands

**Required Input:**
- Test file path OR test pattern OR "all"

**Expected Output:**
- Test results with pass/fail status
- Failure details with line numbers

**Command Pattern:**
```bash
docker compose exec -T -e RAILS_ENV=test app bundle exec rspec [path]
```

---

### 3. @console

**Purpose:** Execute Ruby code in Rails console/runner across all environments (dev/test/prod).

**When to Use:**
- Exploring data via repos
- Testing operations manually
- Updating records in any environment
- Debugging domain logic
- Checking DI container registrations

**When NOT to Use:**
- Running migrations (use db:migrate)
- Long-running processes
- Bulk data operations (write a rake task)

**Required Input:**
- Target environment: `dev` (default), `test`, or `prod`
- Execution mode: `interactive` (console) or `runner` (one-liner)
- Ruby code to execute (for runner mode)

**Expected Output:**
- Console output / return values

**Environment-Specific Behavior:**

**Development:**
```bash
# Interactive console
docker compose exec app bin/rails console

# Runner (one-liner)
docker compose exec -T app bin/rails runner "puts User.count"

# Runner (multi-line)
docker compose exec -T app bin/rails runner "
  user = User.find_by(email_address: 'test@example.com')
  puts user.name
"
```

**Test:**
```bash
# Interactive console
docker compose exec -e RAILS_ENV=test app bin/rails console

# Runner
docker compose exec -T -e RAILS_ENV=test app bin/rails runner "puts User.count"
```

**Production:**
```bash
# Interactive console
kamal app exec "bin/rails console" --reuse -i

# Runner (one-liner)
kamal app exec "bin/rails runner 'puts User.count'" --reuse

# Runner (multi-line)
kamal app exec "bin/rails runner \"
  user = User.find_by(email_address: 'test@example.com')
  puts user.name
\"" --reuse

# For complex operations, use script file:
scp tmp/script.rb rege@pi5main.local:/tmp/script.rb
ssh rege@pi5main.local "docker cp /tmp/script.rb \$(docker ps -q -f name=ismf-race-logger-web):/tmp/script.rb"
kamal app exec "bin/rails runner /tmp/script.rb" --reuse
```

**Rules:**
- Always use `-T` flag for non-interactive runner commands in dev/test
- Use single quotes inside double-quoted runner strings
- For production, use `kamal app exec` with `--reuse` flag
- Use `-i` flag for interactive console in production
- If Zeitwerk or code is broken in prod, deploy fix before running commands

---

### 4. @quality

**Alias:** code-quality-checker

**Purpose:** Run RuboCop and Packwerk to verify code quality.

**When to Use:**
- Before committing changes
- After refactoring
- Verifying architecture boundaries

**When NOT to Use:**
- During exploratory coding (run at end)

**Required Input:**
- None (runs on entire project)
- OR specific file path

**Expected Output:**
- List of violations (if any)
- Auto-fixed issues report

**Command Pattern:**
```bash
docker compose exec -T app bundle exec rubocop -A
docker compose exec app bundle exec packwerk check
```

---

### 5. @curl

**Alias:** api-tester

**Purpose:** Test HTTP endpoints using curl.

**When to Use:**
- Verifying endpoint behavior
- Testing authentication flow
- Debugging API responses

**When NOT to Use:**
- Automated testing (use RSpec request specs)
- Load testing

**Required Input:**
- HTTP method
- Endpoint path
- Request body (if applicable)
- Authentication required (yes/no)

**Expected Output:**
- HTTP response with status code
- Response body

**See:** `docs/DEV_COMMANDS.md` → API Testing with curl

---

### 6. @debug

**Alias:** docker-diagnose

**Purpose:** Diagnose Docker container issues and troubleshoot application problems.

**When to Use:**
- Container won't start
- "Server already running" errors
- Database connection issues
- Service health checks

**When NOT to Use:**
- Application-level bugs
- Test failures

**Required Input:**
- Error message or symptom description

**Expected Output:**
- Diagnosis
- Fix commands

**Common Fixes:**
```bash
# Remove stale PID
docker compose exec app rm -f tmp/pids/server.pid

# Rebuild containers
docker compose down && docker compose up --build

# Check service status
docker compose ps
```

---

### 7. @migration

**Alias:** migration-generator

**Purpose:** Generate database migrations following Rails conventions.

**When to Use:**
- Adding new tables
- Adding/removing columns
- Adding indexes
- Modifying constraints

**When NOT to Use:**
- Data migrations (use rake tasks)
- Complex schema changes (write manually)

**Required Input:**
- Migration name
- Fields with types

**Expected Output:**
- Migration file path
- Generated migration content

**Command Pattern:**
```bash
docker compose exec -T app bin/rails generate migration MigrationName field:type
```

---

### 8. @deploy

**Alias:** deployment-manager

**Purpose:** Deploy code changes to production via GitHub Actions.

**When to Use:**
- After committing code changes that need to go to production
- Checking deployment status
- Understanding the deployment workflow

**When NOT to Use:**
- For local development changes
- When changes don't need to go to production yet
- Emergency fixes (use hotfix branch workflow)

**Required Input:**
- None (automated via CI/CD)

**Expected Output:**
- Deployment status
- GitHub Actions workflow URL

**Deployment Workflow:**

This project uses **GitHub Actions for automated deployment**:

1. **Push code to GitHub:**
   ```bash
   git add .
   git commit -m "Your commit message"
   git push origin main
   ```

2. **GitHub Actions triggers automatically:**
   - Runs tests
   - Builds Docker image
   - Deploys via Kamal to production

3. **Wait for deployment to complete:**
   - Check GitHub Actions tab for workflow status
   - Deployment typically takes 3-5 minutes
   - Production will be updated automatically

4. **Verify deployment:**
   ```bash
   # Check running container version
   kamal app version --reuse
   
   # Check application logs
   kamal app logs --since 5m
   ```

**Important Notes:**
- Manual `kamal deploy` requires secrets and is NOT the normal workflow
- Always push to GitHub and let Actions handle deployment
- After code changes, wait for Actions to complete before testing in production
- Deployment secrets are stored in GitHub repository settings

**Monitoring Deployment:**
- GitHub Actions: https://github.com/YOUR_ORG/ismf-race-logger/actions
- Check commit SHA matches deployed version
- Production URL: https://ismf.taterniczek.pl

---

### 9. @kiosk

**Alias:** kiosk-remote-controller

**Purpose:** Remote control and debug Raspberry Pi kiosk displays (pi5cam) via SSH from macOS.

**When to Use:**
- Refreshing browser on Raspberry Pi after UX changes
- Viewing browser console logs remotely
- Restarting kiosk service
- Checking display resolution and touch detection
- Testing touch interface changes (including web-based virtual keyboard)
- Debugging JavaScript errors on the Pi

**When NOT to Use:**
- Local development testing (use desktop browser with `?touch=1`)
- Production server operations (use `@console` or `@deploy`)
- Ansible playbook changes (modify ansible/*.yml directly)

**Required Input:**
- Action: `refresh`, `logs`, `restart`, `info`, `screenshot`, or custom command
- Target device: `pi5cam.local` (default kiosk)

**Expected Output:**
- Command result or status
- Browser console logs (if requested)
- Device information (if requested)

**Target Kiosk:**
- Hostname: `pi5cam.local`
- User: `rege`
- Display: Raspberry Pi Touch Display 2 (1280×720 landscape)
- Compositor: Weston (Wayland, not X11)
- Browser: Chromium in kiosk mode
- Service: `kiosk.service` (systemd)
- Virtual Keyboard: Web-based (simple-keyboard library)

**Documentation:**
- Kiosk Setup: `docs/KIOSK_DEPLOYMENT.md`
- Touch Display: `docs/TOUCH_DISPLAY.md`

**SSH Connection:**
```bash
# Basic SSH connection
ssh rege@pi5cam.local

# Execute single command
ssh rege@pi5cam.local "command here"
```

**Common Operations:**

**1. Refresh Browser (Hard Reload):**
```bash
# Restart kiosk service (full reload)
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# Or kill and restart browser only
ssh rege@pi5cam.local "pkill chromium && sleep 2"
# Service will auto-restart browser

# Force refresh via URL reload (if remote debugging enabled)
ssh rege@pi5cam.local "curl -s http://localhost:9222/json | \
  jq -r '.[0].webSocketDebuggerUrl' | \
  xargs -I {} wscat -c {} -x '{\"method\":\"Page.reload\",\"params\":{\"ignoreCache\":true}}'"
```

**2. Restart Kiosk Service:**
```bash
# Full restart (Weston + Chromium)
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# Check service status
ssh rege@pi5cam.local "sudo systemctl status kiosk.service"

# Stop service
ssh rege@pi5cam.local "sudo systemctl stop kiosk.service"

# Start service
ssh rege@pi5cam.local "sudo systemctl start kiosk.service"
```

**3. View Logs:**
```bash
# Service logs (Weston + Chromium)
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -n 100"

# Follow logs in real-time
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -f"

# Chromium console logs (if logging enabled)
ssh rege@pi5cam.local "cat ~/.local/share/xorg/Xorg.0.log 2>/dev/null || \
  sudo journalctl -u kiosk.service | grep -i 'console\|error\|warning'"

# Check for errors
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service | grep -i error"
```

**4. Device Information:**
```bash
# Display info (Weston)
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service | grep -i 'output\|display\|resolution'"

# System info
ssh rege@pi5cam.local "uname -a && cat /proc/device-tree/model"

# Check if Weston is running
ssh rege@pi5cam.local "ps aux | grep weston"

# Check if Chromium is running
ssh rege@pi5cam.local "ps aux | grep chromium"

# Touch device info
ssh rege@pi5cam.local "cat /proc/bus/input/devices | grep -A 5 Touch"

# Current kiosk URL
ssh rege@pi5cam.local "grep ExecStart /etc/systemd/system/kiosk.service | grep -oP 'http[^\"]+'"
```

**5. Take Screenshot:**
```bash
# Using Weston screenshot tool
ssh rege@pi5cam.local "WAYLAND_DISPLAY=wayland-1 weston-screenshooter"
# Screenshot saved to ~/wayland-screenshot-*.png

# Download latest screenshot
ssh rege@pi5cam.local "ls -t ~/wayland-screenshot-*.png | head -1" | \
  xargs -I {} scp rege@pi5cam.local:{} ~/Desktop/kiosk-screenshot.png

# Or use grim (if installed)
ssh rege@pi5cam.local "grim /tmp/screenshot.png"
scp rege@pi5cam.local:/tmp/screenshot.png ~/Desktop/
```

**6. Update Kiosk URL:**
```bash
# Using Ansible (recommended)
cd ansible
ansible-playbook -i inventory.yml update-kiosk-url.yml \
  --limit pi5cam -e "new_url=http://192.168.1.233:3005/?touch=1"

# Manual update (not recommended)
ssh rege@pi5cam.local "sudo sed -i 's|http://[^\"]*|http://192.168.1.233:3005/?touch=1|' \
  /etc/systemd/system/kiosk.service && \
  sudo systemctl daemon-reload && \
  sudo systemctl restart kiosk.service"
```

**7. Remote Debugging:**
```bash
# Enable remote debugging (already configured in kiosk setup)
# Chromium runs with --remote-debugging-port=9222

# Check if debugging port is open
ssh rege@pi5cam.local "curl -s http://localhost:9222/json"

# Access from Mac (create SSH tunnel)
ssh -L 9222:localhost:9222 rege@pi5cam.local -N &

# Then open on Mac: chrome://inspect/#devices
# Or direct: http://localhost:9222
```

**Common Workflow for UX Changes:**

```bash
# 1. Make changes to touch display UI
# (edit views, CSS, JavaScript keyboard, etc.)

# 2. Commit and push (if using production URL)
git add .
git commit -m "Improve touch display UX"
git push origin main
# Wait for GitHub Actions deployment (~5 min)

# 3. Restart kiosk to load changes
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# 4. Check if service started correctly
ssh rege@pi5cam.local "sudo systemctl status kiosk.service"

# 5. View logs for errors
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -n 50"

# 6. Test the virtual keyboard
# - Navigate to sign-in page on kiosk display
# - Tap on email or password field
# - Web-based keyboard should slide up from bottom
# - Test typing and audio feedback

# 7. Optional: Take screenshot to verify visually
ssh rege@pi5cam.local "ls -t ~/wayland-screenshot-*.png 2>/dev/null | head -1" || \
  echo "No screenshots found"
```

**For Local Development URL:**

```bash
# If kiosk points to local dev server (http://192.168.1.233:3005)
# Changes are live immediately, just hard refresh browser:
# Method 1: Wait for auto-refresh (if enabled)
# Method 2: Restart service for clean reload
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# Note: Web-based keyboard is part of the page, so any view changes
# require a page reload to see keyboard updates
```

**Prerequisites:**
- SSH key setup for passwordless access: `ssh-copy-id rege@pi5cam.local`
- Ansible inventory configured (see `ansible/inventory.yml`)
- Kiosk service running (set up via Ansible playbook)
- Network connectivity to pi5cam.local

**Troubleshooting:**

```bash
# Service won't start
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -n 100 | grep -i 'error\|failed'"

# Check network connectivity
ping pi5cam.local

# SSH connection test
ssh rege@pi5cam.local "echo 'Connection OK'"

# Check if display is detected
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service | grep -i dsi"

# Restart entire system (last resort)
ssh rege@pi5cam.local "sudo reboot"

# Or use Ansible
cd ansible && ansible-playbook -i inventory.yml reboot-kiosks.yml --limit pi5cam
```

**Quick Reference Commands:**

```bash
# Restart browser
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# View logs
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -f"

# Check status
ssh rege@pi5cam.local "sudo systemctl status kiosk.service"

# Reboot Pi
ssh rege@pi5cam.local "sudo reboot"

# Update URL via Ansible
cd ansible && ansible-playbook -i inventory.yml update-kiosk-url.yml \
  --limit pi5cam -e "new_url=YOUR_URL_HERE"
```

**Security Notes:**
- Only use on trusted local network
- Remote debugging port (9222) is localhost-only by default
- Use SSH key authentication, not passwords
- Kiosk runs as unprivileged user `rege`

**See Also:**
- `docs/ANSIBLE_KIOSK_SETUP.md` — Full kiosk setup guide
- `docs/TOUCH_DISPLAY_UX.md` — Touch display best practices
- `ansible/inventory.yml` — Kiosk configuration
- `ansible/update-kiosk-url.yml` — URL update playbook

---

## Agent Selection Guide

| Problem | Agent |
|---------|-------|
| "Build a new feature" | `@feature` |
| "Run my tests" | `@test` |
| "Check this in console" | `@console` |
| "Update user in production" | `@console` (prod mode) |
| "Fix RuboCop violations" | `@quality` |
| "Test this endpoint" | `@curl` |
| "Container won't start" | `@debug` |
| "Add a database column" | `@migration` |
| "Why is this failing?" | `@debug` |
| "Verify Packwerk boundaries" | `@quality` |
| "Deploy my changes" | `@deploy` |
| "Push to production" | `@deploy` |
| "Refresh kiosk display" | `@kiosk` |
| "Debug touch interface" | `@kiosk` |
| "View kiosk logs" | `@kiosk` |
| "Restart Raspberry Pi browser" | `@kiosk` |

---

## Global vs Project Agents

### Project-Scoped (this repo)
These agents read project-specific documentation:
- `@feature` — reads `docs/ARCHITECTURE.md`, `docs/FEATURE_WORKFLOW.md`
- `@test` — knows Docker command patterns and RAILS_ENV requirements
- `@console` — knows environment-specific console/runner commands, production SSH patterns
- `@quality` — knows RuboCop and Packwerk configuration
- `@deploy` — knows GitHub Actions deployment workflow
- `@kiosk` — knows Raspberry Pi kiosk control, Weston/Wayland commands, pi5cam configuration

### Globally Reusable
These agents work across projects:
- `@debug` — generic Docker troubleshooting
- `@curl` — HTTP endpoint testing
- `@migration` — Rails migration generation
- `@deploy` — CI/CD deployment patterns

---

## Adding New Agents

When adding a new agent:

1. Document in this file:
   - Purpose
   - When to Use / When NOT to Use
   - Required Input
   - Expected Output

2. If shell-based, add to `.zed/tasks.json`

3. Keep agents stateless (stdin → stdout)

---

## See Also

- `.rules` — AI constraints
- `docs/DEV_COMMANDS.md` — All shell commands
- `docs/FEATURE_WORKFLOW.md` — Feature development phases
- `docs/ARCHITECTURE.md` — Project architecture
- `.zed/tasks.json` — Zed task launchers