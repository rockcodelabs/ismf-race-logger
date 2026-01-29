# Touch Screen Implementation - Pi Deployment Guide

**Version:** 2.0  
**Date:** 2025-01-29  
**Purpose:** Deploy and test new touch screen implementation on Raspberry Pi

---

## Overview

This guide walks through deploying the new touch screen implementation to the Raspberry Pi 7" Touch Display 2, including:

- Cleaning up old keyboard code
- Applying new Chromium flags (disable native keyboard)
- Deploying application changes
- Testing on actual hardware

---

## Prerequisites

- Raspberry Pi 5 with Touch Display 2 (800×480)
- SSH access to Pi (`ssh pi@pi5main.local`)
- Ansible installed locally
- GitHub repository access
- Code changes committed and pushed

---

## Deployment Steps

### Step 1: Push Code to GitHub

```bash
# On your Mac, commit all changes
cd ismf-race-logger
git add .
git commit -m "Refactor: Touch screen implementation with simple-keyboard"
git push origin main

# GitHub Actions will automatically deploy (3-5 minutes)
# Monitor at: https://github.com/YOUR_USERNAME/ismf-race-logger/actions
```

**Wait for GitHub Actions to complete before proceeding.**

---

### Step 2: Update Kiosk Configuration (Ansible)

The new Chromium flags are already in `ansible/inventory.yml`:

```yaml
chromium_flags:
  - --kiosk
  - --ozone-platform=wayland
  - --enable-features=UseOzonePlatform  # VirtualKeyboard REMOVED
  - --noerrdialogs
  - --disable-infobars
  - --disable-session-crashed-bubble
  - --disable-features=TranslateUI,VirtualKeyboard  # ADDED VirtualKeyboard
  - --disable-sync
  - --disable-translate
  - --disable-background-timer-throttling
  - --disable-renderer-backgrounding
  - --disable-backgrounding-occluded-windows
  - --enable-gpu-rasterization
  - --enable-zero-copy
  - --ignore-gpu-blocklist
  - --no-first-run
  - --incognito
  - --touch-events=enabled
  - --disable-touch-keyboard  # CHANGED from --enable-virtual-keyboard
```

**Apply the configuration:**

```bash
# Navigate to ansible directory
cd ansible

# Run the playbook to update kiosk
ansible-playbook -i inventory.yml setup-kiosk.yml

# Or just update the service (faster)
ansible-playbook -i inventory.yml update-kiosk-url.yml
```

---

### Step 3: SSH to Pi and Clean Browser Cache

```bash
# SSH to Pi
ssh pi@pi5main.local

# Stop the kiosk service
sudo systemctl stop kiosk.service

# Clear Chromium cache and cookies
rm -rf ~/.config/chromium/Default/Cache/*
rm -rf ~/.config/chromium/Default/Cookies*
rm -rf ~/.config/chromium/Default/'Service Worker'/*

# Clear localStorage (where old keyboard JS might be cached)
rm -rf ~/.config/chromium/Default/'Local Storage'/*

# Verify kiosk service configuration
sudo systemctl cat kiosk.service | grep chromium

# Should see:
#   --disable-features=TranslateUI,VirtualKeyboard
#   --disable-touch-keyboard
```

---

### Step 4: Verify Application is Updated

```bash
# Still on Pi
# Check if new code is deployed (via Kamal)
curl -I http://pi5main.local:3005

# Should return 200 OK

# Check if touch.css is available
curl http://pi5main.local:3005/assets/touch.css | head -20

# Should see touch display CSS
```

---

### Step 5: Restart Kiosk

```bash
# Still on Pi
# Restart kiosk service
sudo systemctl restart kiosk.service

# Check status
sudo systemctl status kiosk.service

# Follow logs
sudo journalctl -u kiosk.service -f
```

**Expected logs:**
```
Starting Web Kiosk for ISMF Race Logger...
Started Web Kiosk for ISMF Race Logger.
[Chromium output with --disable-touch-keyboard flag]
```

---

### Step 6: Test on Touch Display

#### 6.1 Visual Verification

**Check the display:**
- ✅ Touch layout loads automatically (no `?touch=1` needed)
- ✅ Large buttons and text
- ✅ ISMF logo visible
- ✅ "Sign In" button large and prominent
- ✅ NO desktop toggle link

#### 6.2 Touch Navigation

**Home page:**
- ✅ NO navigation bar (home page only)
- ✅ Large "Sign In" button (120px height)
- ✅ Footer at bottom

**Touch "Sign In":**
- ✅ Navigates to login page
- ✅ Navigation bar appears (Home, Back, Hamburger)
- ✅ Page title shows "Sign In"

#### 6.3 Virtual Keyboard Test

**Touch email input field:**
- ✅ **ONLY custom keyboard appears at bottom**
- ❌ **NO native Chromium keyboard** (this is the key test!)
- ✅ Keyboard has QWERTY layout
- ✅ Numbers row (1-9, 0)
- ✅ **Preview display visible** (left of spacebar, green background)
- ✅ Preview shows "Type here..." when empty

**Type characters:**
- ✅ Characters appear in email field
- ✅ **Preview updates with typed text**
- ✅ Audio beep on key press
- ✅ Visual feedback (button press animation)

**Touch password field:**
- ✅ Keyboard stays visible
- ✅ **Preview shows bullets (•••) instead of text**
- ✅ Characters masked in password field

**Test keyboard features:**
- ✅ Shift key toggles uppercase
- ✅ Backspace deletes characters
- ✅ Spacebar adds space
- ✅ @ symbol works
- ✅ Enter key submits form

#### 6.4 Form Submission

**Enter credentials:**
- ✅ Type valid email with keyboard
- ✅ Type valid password with keyboard
- ✅ Click "Sign In" button
- ✅ Form submits successfully
- ✅ Redirects to appropriate page

#### 6.5 Cookie Persistence

**Reboot test:**
```bash
# On Pi
sudo reboot
```

**After reboot:**
- ✅ Kiosk starts automatically
- ✅ Touch mode is active (no `?touch=1` needed)
- ✅ Cookie persists: `touch_display=1`

---

## Troubleshooting

### Issue: Native Keyboard Still Appears

**Symptoms:**
- Both native Chromium keyboard AND custom keyboard appear
- Keyboards overlap

**Solution:**

```bash
# SSH to Pi
ssh pi@pi5main.local

# Check current Chromium flags
ps aux | grep chromium | grep -o '\-\-[^ ]*keyboard[^ ]*'

# Should see:
#   --disable-touch-keyboard
#   (NOT --enable-virtual-keyboard)

# If flags are wrong, update service
sudo systemctl cat kiosk.service | grep flag

# Restart service
sudo systemctl restart kiosk.service
```

---

### Issue: Touch Mode Not Auto-Detected

**Symptoms:**
- Desktop layout shows instead of touch layout
- Need to manually add `?touch=1`

**Solution:**

```bash
# Check browser console logs
sudo journalctl -u kiosk.service -n 100 | grep -i touch

# Should see:
#   "📱 Touch detection controller connected"
#   "✅ Pi touch display detected! Setting cookie..."
#   "🔄 Reloading page to apply touch mode..."

# Clear cookies and reload
rm -rf ~/.config/chromium/Default/Cookies*
sudo systemctl restart kiosk.service
```

---

### Issue: Keyboard Doesn't Appear

**Symptoms:**
- Touch input, no keyboard shows
- Console shows "Failed to load keyboard"

**Check importmap:**

```bash
# On Pi, check network tab
curl http://pi5main.local:3005 | grep simple-keyboard

# Should see:
#   <script type="importmap">...simple-keyboard...</script>

# Check if CDN is accessible
curl -I https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/index.min.js

# Should return 200 OK
```

**Check browser console:**

```bash
# View Chromium console logs
sudo journalctl -u kiosk.service -f | grep -E "(keyboard|error|Keyboard)"
```

---

### Issue: Buttons Not Clickable

**Symptoms:**
- Touch buttons, nothing happens
- Visual feedback missing

**Check CSS:**

```bash
# Verify touch.css loaded
curl http://pi5main.local:3005/assets/touch.css | grep "touch-btn"

# Should see touch button styles
```

**Check JavaScript:**

```bash
# Check if Stimulus controllers loaded
sudo journalctl -u kiosk.service | grep "controller connected"

# Should see:
#   🎹 Keyboard controller connected
#   📱 Touch detection controller connected
#   🧭 Touch navigation controller connected
```

---

### Issue: Input Field Hidden by Keyboard

**Symptoms:**
- Type in input, can't see what you're typing
- Keyboard covers input field

**This is why we have the preview display!**

The preview display (left of spacebar) shows what you're typing even if the input is covered.

**Verify preview works:**
- ✅ Type characters
- ✅ Preview updates
- ✅ Password shows bullets (•••)

---

## Remote Debugging from Mac

### View Pi Logs from Mac

```bash
# SSH and follow logs
ssh pi@pi5main.local "sudo journalctl -u kiosk.service -f"

# Or use grep to filter
ssh pi@pi5main.local "sudo journalctl -u kiosk.service -f" | grep -E "(keyboard|error|touch)"
```

### Remote Browser Console

**Enable remote debugging:**

```bash
# SSH to Pi
ssh pi@pi5main.local

# Stop kiosk
sudo systemctl stop kiosk.service

# Start Chromium with remote debugging
chromium --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug &

# Open the URL
chromium --kiosk http://pi5main.local:3005?touch=1 &
```

**Connect from Mac:**

1. Open Chrome on Mac
2. Navigate to `chrome://inspect`
3. Configure: Add `pi5main.local:9222`
4. Click "Inspect" on the target

Now you can use DevTools remotely!

---

## Performance Verification

### Check Memory Usage

```bash
# On Pi
free -h

# Chromium should use ~300-500MB
```

### Check CPU Usage

```bash
# On Pi
top

# Chromium should use <50% CPU when idle
```

### Check Page Load Time

```bash
# On Mac
curl -w "@-" -o /dev/null -s http://pi5main.local:3005?touch=1 <<'EOF'
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_starttransfer:  %{time_starttransfer}\n
time_total:  %{time_total}\n
EOF

# Should be <2 seconds total
```

---

## Rollback Plan

If the new implementation has issues:

### Quick Rollback (Emergency)

```bash
# On Pi
# Stop kiosk
sudo systemctl stop kiosk.service

# Revert to previous Kamal deployment
# (from Mac)
ssh pi@pi5main.local
cd /path/to/app
kamal rollback

# Restart kiosk
sudo systemctl restart kiosk.service
```

### Full Rollback (Restore Old Config)

```bash
# Restore old Chromium flags
# Edit ansible/inventory.yml and change:
#   --disable-touch-keyboard → --enable-virtual-keyboard
#   Remove: --disable-features=VirtualKeyboard

# Re-run Ansible
cd ansible
ansible-playbook -i inventory.yml setup-kiosk.yml

# Restart kiosk
ssh pi@pi5main.local
sudo systemctl restart kiosk.service
```

---

## Post-Deployment Checklist

After successful deployment:

- [ ] Touch mode auto-activates (no `?touch=1`)
- [ ] **ONLY custom keyboard appears (no native keyboard)**
- [ ] **Input preview shows typed text**
- [ ] **Preview shows bullets for passwords**
- [ ] Navigation bar works (Home, Back, Sign Out)
- [ ] Buttons are clickable with touch
- [ ] Form submission works
- [ ] Audio feedback on keypresses
- [ ] Cookie persists after reboot
- [ ] Performance is acceptable (<2s load)
- [ ] No JavaScript errors in logs
- [ ] Complete manual checklist: `docs/TOUCH_TESTING_CHECKLIST.md`

---

## Monitoring

### 24-Hour Monitoring

After deployment, monitor for 24 hours:

```bash
# Set up continuous log monitoring
ssh pi@pi5main.local "sudo journalctl -u kiosk.service -f" > pi-logs.txt
```

**Watch for:**
- ❌ JavaScript errors
- ❌ Keyboard loading failures
- ❌ Memory leaks (increasing memory usage)
- ❌ Repeated service restarts
- ✅ Successful page loads
- ✅ Successful form submissions

---

## Success Criteria

Deployment is successful when:

1. ✅ **Native keyboard disabled** - Only custom keyboard appears
2. ✅ **Input preview works** - Shows text left of spacebar
3. ✅ **Password masking works** - Shows bullets in preview
4. ✅ Touch detection automatic (no URL param needed)
5. ✅ Cookie persists across reboots
6. ✅ All manual tests pass (see `TOUCH_TESTING_CHECKLIST.md`)
7. ✅ No errors in logs for 24 hours
8. ✅ User feedback is positive

---

## Quick Commands Reference

```bash
# Deployment
git push origin main                          # Deploy via GitHub Actions

# Ansible
cd ansible
ansible-playbook -i inventory.yml setup-kiosk.yml

# Pi Commands
ssh pi@pi5main.local                          # SSH to Pi
sudo systemctl restart kiosk.service          # Restart kiosk
sudo journalctl -u kiosk.service -f           # View logs
ps aux | grep chromium                        # Check Chromium process
rm -rf ~/.config/chromium/Default/Cache/*     # Clear cache

# Verification
curl http://pi5main.local:3005?touch=1        # Test app responds
curl http://pi5main.local:3005/assets/touch.css | head  # Check CSS
```

---

## Contact & Support

If issues persist after following this guide:

1. Check GitHub Issues
2. Review full documentation: `docs/TOUCH_SCREEN_IMPLEMENTATION.md`
3. Run test suite: `./bin/test-touch --verbose`
4. Consult troubleshooting guide: `docs/TOUCH_SCREEN_IMPLEMENTATION.md#troubleshooting`

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-29  
**Next Review:** After first production deployment