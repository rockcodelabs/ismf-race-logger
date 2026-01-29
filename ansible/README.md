# Ansible Kiosk Deployment

This directory contains Ansible playbooks for deploying the ISMF Race Logger to Raspberry Pi 5 kiosks with 7" touch displays.

---

## Overview

The kiosk setup configures a Raspberry Pi 5 to:
- Boot directly to a web browser in kiosk mode (no desktop)
- Display the ISMF Race Logger at 1280×720 resolution (landscape)
- Support touch input with the app's built-in virtual keyboard
- Auto-start on boot and restart on failure
- Rotate display 90° for portrait mode (configurable)

**Key Components:**
- **Weston**: Wayland compositor (lightweight, no X11)
- **Chromium**: Browser in kiosk mode with touch support
- **seatd**: Seat management for direct hardware access
- **simple-keyboard**: JavaScript virtual keyboard (built into app)

---

## Quick Start

### 1. Prerequisites

On your Mac:
```bash
# Install Ansible
pip3 install -r requirements.txt

# Verify SSH access to Pi
ssh rege@pi5cam.local
```

On the Raspberry Pi:
- Raspberry Pi OS (Bookworm or Trixie)
- SSH enabled
- User with sudo privileges
- Network connectivity

### 2. Configure Inventory

Copy and edit the inventory file:
```bash
cp inventory.example.yml inventory.yml
nano inventory.yml
```

Example configuration:
```yaml
all:
  children:
    kiosks:
      hosts:
        pi5cam:
          ansible_host: pi5cam.local
          kiosk_url: http://192.168.1.233:3005/?touch=1
          display_rotation: rotate-90
      vars:
        ansible_user: rege
        chromium_flags:
          - --kiosk
          - --disable-features=VirtualKeyboard
          - --disable-touch-keyboard
          # ... (see inventory.yml for full list)
```

### 3. Deploy Kiosk

```bash
# Full setup (first time or major changes)
ansible-playbook -i inventory.yml setup-kiosk.yml

# Update kiosk URL only
ansible-playbook -i inventory.yml update-kiosk-url.yml

# Reboot all kiosks
ansible-playbook -i inventory.yml reboot-kiosks.yml
```

### 4. Verify Deployment

```bash
ssh rege@pi5cam.local

# Check service status
sudo systemctl status kiosk

# View live logs
sudo journalctl -u kiosk -f

# Restart kiosk
sudo systemctl restart kiosk
```

---

## Playbooks

### `setup-kiosk.yml`

**Purpose:** Complete kiosk setup from scratch

**What it does:**
1. Updates system packages
2. Sets boot target to multi-user (no desktop)
3. Installs Weston, Chromium, seatd
4. Configures display rotation
5. Deploys systemd service
6. Optimizes boot parameters

**When to use:**
- First-time setup
- After Pi OS reinstall
- Major configuration changes

**Usage:**
```bash
ansible-playbook -i inventory.yml setup-kiosk.yml
```

**Reboot required:** Yes (handled automatically or run `reboot-kiosks.yml`)

---

### `update-kiosk-url.yml`

**Purpose:** Change the URL the kiosk displays

**What it does:**
1. Updates systemd service with new URL
2. Reloads and restarts kiosk service

**When to use:**
- Switching between dev/staging/production
- Changing app server IP/port

**Usage:**
```bash
ansible-playbook -i inventory.yml update-kiosk-url.yml
```

**Reboot required:** No (service restarts automatically)

---

### `reboot-kiosks.yml`

**Purpose:** Reboot all configured kiosks

**What it does:**
1. Gracefully reboots all hosts in the `kiosks` group
2. Waits for systems to come back online

**When to use:**
- After setup-kiosk.yml (if not auto-rebooted)
- After system updates
- Troubleshooting

**Usage:**
```bash
ansible-playbook -i inventory.yml reboot-kiosks.yml
```

---

## Configuration

### Inventory Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ansible_host` | Yes | - | IP or hostname of Pi |
| `ansible_user` | Yes | - | SSH user (usually `rege`) |
| `kiosk_url` | Yes | - | Full URL to display (include `?touch=1`) |
| `display_rotation` | No | `rotate-90` | `normal`, `rotate-90`, `rotate-180`, `rotate-270` |
| `chromium_flags` | No | See inventory.yml | Browser behavior flags |

### Chromium Flags

Key flags for kiosk mode:
```yaml
chromium_flags:
  - --kiosk                          # Full-screen, no UI
  - --ozone-platform=wayland         # Use Wayland (required for Weston)
  - --disable-features=VirtualKeyboard  # ❌ Disable native keyboard
  - --disable-touch-keyboard         # ❌ Disable native keyboard
  - --touch-events=enabled           # ✅ Enable touch input
  - --noerrdialogs                   # No error popups
  - --disable-infobars               # No info bars
  - --incognito                      # No history/cache
```

**Important:** The `--disable-features=VirtualKeyboard` and `--disable-touch-keyboard` flags prevent Chromium's native keyboard from conflicting with the app's simple-keyboard implementation.

---

## Troubleshooting

### Issue: "Failure keyboard" error during boot

**Symptoms:**
- Boot logs show: `Failure keyboard ...`
- Kiosk service fails or delays startup
- `journalctl -u kiosk` shows squeekboard errors

**Root Cause:**
An old service configuration tried to launch `squeekboard` (native on-screen keyboard), but:
- It's not needed (app has built-in JavaScript keyboard)
- It conflicts with Chromium kiosk mode
- It's been removed from latest Ansible

**Solution:**

1. **Redeploy with latest Ansible** (recommended):
   ```bash
   cd ansible
   ansible-playbook -i inventory.yml setup-kiosk.yml
   ```

2. **Or manually fix on Pi**:
   ```bash
   ssh rege@pi5cam.local
   sudo systemctl stop kiosk
   sudo nano /etc/systemd/system/kiosk.service
   # Remove any 'squeekboard' references
   sudo systemctl daemon-reload
   sudo systemctl restart kiosk
   ```

3. **Verify no squeekboard references**:
   ```bash
   ssh rege@pi5cam.local
   cat /etc/systemd/system/kiosk.service | grep squeekboard
   # Should return nothing
   ```

**Prevention:**
- Use latest Ansible playbooks (squeekboard removed)
- The app's virtual keyboard is JavaScript-based (simple-keyboard)
- No native on-screen keyboard should be installed

---

### Issue: Kiosk shows blank screen

**Check logs:**
```bash
ssh rege@pi5cam.local
sudo journalctl -u kiosk -f
```

**Common causes:**

1. **Network not ready:**
   - Weston starts before network is up
   - Solution: Wait 30 seconds, or check `After=network-online.target` in service

2. **Chromium can't reach URL:**
   - Check URL in inventory.yml
   - Ping the app server from Pi: `ping 192.168.1.233`
   - Verify app is running: `curl http://192.168.1.233:3005`

3. **Weston compositor failed:**
   - Check GPU memory: `/boot/firmware/config.txt` should have `gpu_mem=256`
   - Check permissions: User should be in `video,input,render,tty` groups
   - Verify seatd is running: `sudo systemctl status seatd`

---

### Issue: Touch not working

**Check touch device:**
```bash
ssh rege@pi5cam.local
ls /dev/input/event*
# Should show touch device
```

**Check user permissions:**
```bash
groups rege
# Should include: video input render tty
```

**Add to groups if missing:**
```bash
sudo usermod -aG video,input,render,tty rege
```

**Verify Chromium flags:**
```bash
cat /etc/systemd/system/kiosk.service | grep touch-events
# Should show: --touch-events=enabled
```

---

### Issue: Keyboard doesn't appear when tapping inputs

**This is normal!** The keyboard is **JavaScript-based** (simple-keyboard), not a system service.

**Expected behavior:**
1. Tap text input
2. JavaScript keyboard appears from bottom of screen
3. Type using on-screen keyboard
4. Tap outside or "Enter" to dismiss

**If keyboard still doesn't show:**
1. Check browser console (remote debugging):
   ```bash
   # On Pi - enable remote debugging
   sudo nano /etc/systemd/system/kiosk.service
   # Add to chromium flags: --remote-debugging-port=9222
   
   # On Mac - forward port and visit in Chrome
   ssh -L 9222:localhost:9222 rege@pi5cam.local
   # Chrome: chrome://inspect
   ```

2. Verify simple-keyboard loaded:
   - Open DevTools
   - Console: `window.SimpleKeyboard` (should be defined)

3. Check Stimulus controller:
   - Console: `document.querySelector('[data-controller*="keyboard"]')`
   - Should find elements with `data-controller="keyboard"`

---

### Issue: Display rotation not working

**Check Weston config:**
```bash
ssh rege@pi5cam.local
cat /etc/xdg/weston/weston.ini | grep transform
# Should show your rotation
```

**Valid rotation values:**
- `normal` - No rotation (landscape)
- `rotate-90` - Portrait (most common for 7" display)
- `rotate-180` - Upside-down landscape
- `rotate-270` - Portrait (inverted)

**Update rotation:**
```bash
# In inventory.yml, change:
display_rotation: rotate-90

# Then redeploy
ansible-playbook -i inventory.yml setup-kiosk.yml
```

---

### Emergency Access

If kiosk is stuck or unresponsive:

**SSH access:**
```bash
ssh rege@pi5cam.local
sudo systemctl stop kiosk  # Stop kiosk
# Do your troubleshooting
sudo systemctl start kiosk  # Restart when done
```

**TTY console:**
```
Press: CTRL + ALT + F2
Login: rege / (password)
Stop kiosk: sudo systemctl stop kiosk
Exit TTY: CTRL + ALT + F1 (back to kiosk)
```

**Power cycle:**
```bash
# Soft reboot (preferred)
ansible-playbook -i inventory.yml reboot-kiosks.yml

# Or via SSH
ssh rege@pi5cam.local sudo reboot

# Or hard power cycle
# Unplug power, wait 5 seconds, plug back in
```

---

## File Structure

```
ansible/
├── README.md                    # This file
├── ansible.cfg                  # Ansible configuration
├── inventory.example.yml        # Template inventory
├── inventory.yml               # Your inventory (gitignored)
├── setup-kiosk.yml             # Main setup playbook
├── update-kiosk-url.yml        # URL update playbook
├── reboot-kiosks.yml           # Reboot playbook
├── requirements.txt            # Python dependencies
├── templates/
│   ├── kiosk.service.j2        # Systemd service template
│   └── weston.ini.j2           # Weston compositor config
└── ansible.log                 # Execution logs
```

---

## Best Practices

### Development Workflow

1. **Dev on Mac**: Code and test with `?touch=1` parameter
2. **Commit changes**: Push to GitHub
3. **Deploy via GitHub Actions**: Automatic Kamal deployment
4. **Update kiosk URL**: If needed (usually dev server URL doesn't change)

### Production Deployment

1. **Push to main branch**: Triggers GitHub Actions
2. **Wait for deployment**: 3-5 minutes for Kamal deploy
3. **Verify on kiosk**: Should auto-refresh or restart browser

### Kiosk URLs

**Development (local network):**
```yaml
kiosk_url: http://192.168.1.233:3005/?touch=1
```

**Production (deployed app):**
```yaml
kiosk_url: https://your-production-domain.com/?touch=1
```

**Always include `?touch=1`** - This forces touch variant, bypassing auto-detection.

---

## Service Management

### Systemd Commands

```bash
# Status
sudo systemctl status kiosk

# Start/Stop/Restart
sudo systemctl start kiosk
sudo systemctl stop kiosk
sudo systemctl restart kiosk

# Enable/Disable auto-start
sudo systemctl enable kiosk   # Start on boot (default)
sudo systemctl disable kiosk  # Don't start on boot

# View logs
sudo journalctl -u kiosk -f          # Follow logs
sudo journalctl -u kiosk -n 100      # Last 100 lines
sudo journalctl -u kiosk --since today  # Today's logs
```

### Process Management

```bash
# Find kiosk processes
ps aux | grep -E 'weston|chromium'

# Kill stuck processes (if systemctl stop fails)
sudo pkill -9 weston
sudo pkill -9 chromium

# Restart after manual kill
sudo systemctl start kiosk
```

---

## Architecture

### Boot Sequence

1. **Systemd** starts `multi-user.target` (no desktop)
2. **seatd.service** starts (seat management)
3. **network-online.target** waits for network
4. **kiosk.service** starts:
   - Wait 3 seconds (stability)
   - Launch **Weston** compositor (Wayland)
   - Launch **Chromium** in kiosk mode with configured URL

### Display Stack

```
Hardware (HDMI/DSI)
    ↓
Kernel DRM driver
    ↓
Weston compositor (Wayland)
    ↓
Chromium browser
    ↓
ISMF Race Logger web app
    ↓
simple-keyboard (JavaScript)
```

**No X11, no desktop, no native keyboard** - Pure Wayland stack for minimal overhead.

---

## Additional Resources

- **Touch Screen Guide**: `../docs/TOUCH_SCREEN_IMPLEMENTATION.md`
- **Development Commands**: `../docs/DEV_COMMANDS.md`
- **Agent Reference**: `../AGENTS.md`
- **Raspberry Pi Docs**: https://www.raspberrypi.com/documentation/

---

## Support

For issues:
1. Check troubleshooting section above
2. Review logs: `sudo journalctl -u kiosk -f`
3. Consult `TOUCH_SCREEN_IMPLEMENTATION.md` for app-specific keyboard issues
4. Check GitHub Issues for similar problems

**Remember:** The virtual keyboard is JavaScript, not a system service. If keyboard doesn't work, debug the web app, not the Pi configuration.