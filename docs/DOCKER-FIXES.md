# Docker Fixes - December 2024

## Issues Fixed

This document explains the Docker-related issues that were fixed and how to prevent them in the future.

## Issue 1: "Server Already Running" Error

### Problem

```
A server is already running (pid: 1, file: /rails/tmp/pids/server.pid).
Exiting
```

This occurs when Docker containers are stopped ungracefully (e.g., with `docker compose down` or system restart), leaving behind a stale PID file in `tmp/pids/server.pid`.

### Root Cause

Rails creates a PID file when the server starts. If the container is stopped without proper cleanup (SIGTERM not handled gracefully), the PID file remains. When the container restarts, Rails sees the PID file and refuses to start.

### Solution

Created a custom entrypoint script (`bin/dev-entrypoint`) that automatically removes stale PID files on container startup:

```bash
#!/bin/bash -e

# Remove stale PID file if it exists (prevents "server already running" error)
if [ -f tmp/pids/server.pid ]; then
  echo "Removing stale PID file..."
  rm -f tmp/pids/server.pid
fi

# Execute the command passed to the container
exec "${@}"
```

### Changes Made

1. **Created**: `bin/dev-entrypoint` - Custom entrypoint script
2. **Updated**: `Dockerfile.dev` - Added entrypoint configuration
3. **Updated**: `docker-compose.yml` - Explicitly set entrypoint for app and tailwind services

### Verification

After starting containers, check logs:
```bash
docker compose logs app | grep "Removing stale PID file"
```

You should see this message on startup if a PID file existed.

## Issue 2: "watchman: not found" Warning

### Problem

```
ismf-tailwind | sh: 1: watchman: not found
```

### Root Cause

TailwindCSS CLI tries to use Facebook's `watchman` file-watching tool if available. The warning appears because `watchman` is not installed in the container and is not available in default Debian package repositories.

### Solution

**No action needed** - this is a harmless warning.

- Watchman is an **optional optimization** for TailwindCSS
- TailwindCSS has its own built-in file watching that works perfectly
- Installing watchman would require:
  - Adding custom repositories, OR
  - Building from source (adds complexity and build time)
- The warning does not affect functionality

### Documentation

Updated `CLAUDE.md` to explain this warning is expected and harmless:

```markdown
### "watchman: not found" warning

The Tailwind container may show `sh: 1: watchman: not found`. This is **harmless and expected**. 
Watchman is an optional Facebook file-watching tool that Tailwind can use for optimization, 
but it's not available in default Debian repositories and is not required.

**TL;DR**: Ignore this warning. Tailwind CSS works perfectly fine without watchman.
```

### Verification

Tailwind still processes files successfully - check logs:
```bash
docker compose logs tailwind | grep "Done in"
```

You should see: `Done in XXXms` indicating successful compilation.

## How to Use

### Fresh Start

```bash
# Stop everything
docker compose down

# Build with latest fixes
docker compose build

# Start all services
docker compose up -d

# Check logs
docker compose logs -f app
docker compose logs -f tailwind
```

### Quick Restart

The entrypoint script handles PID cleanup automatically:
```bash
docker compose restart app
```

### Manual PID Cleanup (if needed)

```bash
docker compose exec app rm -f tmp/pids/server.pid
docker compose restart app
```

## Future Maintenance

### If PID Issues Return

1. Check that `bin/dev-entrypoint` is executable:
   ```bash
   ls -la bin/dev-entrypoint
   ```
   Should show: `-rwxr-xr-x`

2. Verify entrypoint is set in `docker-compose.yml`:
   ```yaml
   app:
     entrypoint: ["/rails/bin/dev-entrypoint"]
   ```

3. Rebuild containers:
   ```bash
   docker compose build --no-cache app
   ```

### If Watchman Warning Bothers You

Option 1: **Suppress the warning** (update docker-compose.yml):
```yaml
tailwind:
  command: >
    sh -c "bundle exec tailwindcss 
    -i ./app/assets/tailwind/application.css 
    -o ./app/assets/builds/tailwind.css 
    --watch=always 2>&1 | grep -v 'watchman: not found' || true"
```

Option 2: **Install watchman from source** (adds ~2-3 minutes to build time):
```dockerfile
# In Dockerfile.dev, add before COPY commands:
RUN apt-get update && \
    apt-get install -y python3 && \
    git clone https://github.com/facebook/watchman.git /tmp/watchman && \
    cd /tmp/watchman && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    rm -rf /tmp/watchman
```

**Recommendation**: Keep it as-is. The warning is harmless and adding watchman complicates the build.

## Testing

After applying fixes, verify:

1. **Server starts successfully**:
   ```bash
   docker compose up -d app
   docker compose logs app | grep "Listening on"
   ```

2. **Tailwind compiles successfully**:
   ```bash
   docker compose logs tailwind | grep "Done in"
   ```

3. **App is accessible**:
   ```bash
   curl -I http://localhost:3003
   # Should return: HTTP/1.1 200 OK
   ```

4. **Restart works without errors**:
   ```bash
   docker compose restart app
   docker compose logs app
   # Should show "Removing stale PID file..." then start successfully
   ```

## References

- Custom entrypoint: `bin/dev-entrypoint`
- Docker config: `docker-compose.yml`
- Development Dockerfile: `Dockerfile.dev`
- Documentation: `CLAUDE.md` (Troubleshooting section)

## Summary

| Issue | Status | Action Required |
|-------|--------|-----------------|
| Stale PID files | ✅ Fixed | None - automatic cleanup via entrypoint |
| Watchman warning | ⚠️ Harmless | None - warning can be ignored |

Both issues are resolved. The development environment now starts reliably without manual intervention.