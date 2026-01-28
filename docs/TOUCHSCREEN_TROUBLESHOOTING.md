# Touchscreen Troubleshooting Guide

**DSI Display Touch Issues on Raspberry Pi 5**

This guide helps diagnose and fix touchscreen problems on Raspberry Pi 5 kiosks using DSI displays (particularly 7-inch displays with Goodix touch controllers).

---

## Quick Fix (If Touch Stopped Working)

If your kiosk was working but touch suddenly stopped:

```bash
# SSH into the Pi
ssh rege@pi5cam.local

# Run the touch initialization script
sudo /usr/local/bin/init-touchscreen.sh

# Restart the kiosk
sudo systemctl restart kiosk.service
```

---

## Table of Contents

- [Symptoms](#symptoms)
- [Root Cause](#root-cause)
- [Automated Fix](#automated-fix)
- [Manual Diagnosis](#manual-diagnosis)
- [Verification Steps](#verification-steps)
- [Common Issues](#common-issues)
- [Hardware-Specific Notes](#hardware-specific-notes)

---

## Symptoms

### No Touch Response
- Display shows the kiosk correctly
- You can see the application
- Touching the screen does nothing
- Buttons and UI elements don't respond

### Touch Works But Coordinates Are Wrong
- Touch registers but at wrong location
- Touch is offset or inverted
- Multi-touch gestures don't work

---

## Root Cause

**The Goodix touch controller on DSI displays often fails to initialize properly on Raspberry Pi 5.**

Error in dmesg:
```
Goodix-TS 10-005d: Error reading 1 bytes from 0x8140: -121
Goodix-TS 10-005d: I2C communication failure: -121
Goodix-TS 10-005d: probe with driver Goodix-TS failed with error -121
```

This is an I2C timing issue during boot. The touch controller starts before the I2C bus is fully ready.

---

## Automated Fix

The Ansible playbook (`setup-kiosk.yml`) automatically installs a fix that:

1. **Creates initialization script**: `/usr/local/bin/init-touchscreen.sh`
2. **Creates systemd service**: `touchscreen-init.service`
3. **Runs before kiosk starts**: Ensures touch is ready

### Verify Automated Fix Is Installed

```bash
# Check if the service exists
systemctl status touchscreen-init.service

# Should show:
#   Loaded: loaded
#   Active: active (exited)
```

### If Not Installed, Install Manually

```bash
# 1. Create the initialization script
sudo tee /usr/local/bin/init-touchscreen.sh > /dev/null <<'EOF'
#!/bin/bash
# Initialize Goodix touchscreen on DSI display
# This script works around I2C initialization issues on Pi 5

# Wait for I2C bus to be ready
sleep 2

# Unbind the failed driver
echo '10-005d' | tee /sys/bus/i2c/drivers/Goodix-TS/unbind 2>/dev/null || true

# Wait a moment
sleep 1

# Rebind the driver
echo '10-005d' | tee /sys/bus/i2c/drivers/Goodix-TS/bind 2>/dev/null || true

# Wait for device to initialize
sleep 2

# Check if touch device appeared
if ls /dev/input/by-path/*touch* >/dev/null 2>&1 || ls /dev/input/event5 >/dev/null 2>&1; then
    echo "Touch device initialized successfully"
    exit 0
else
    echo "Touch device initialization may have failed, but continuing"
    exit 0
fi
EOF

# 2. Make it executable
sudo chmod +x /usr/local/bin/init-touchscreen.sh

# 3. Create systemd service
sudo tee /etc/systemd/system/touchscreen-init.service > /dev/null <<'EOF'
[Unit]
Description=Initialize DSI Touchscreen
After=local-fs.target
Before=kiosk.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/init-touchscreen.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 4. Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable touchscreen-init.service
sudo systemctl start touchscreen-init.service

# 5. Restart kiosk
sudo systemctl restart kiosk.service
```

---

## Manual Diagnosis

### Step 1: Check if Touch Device Exists

```bash
# List all input devices
cat /proc/bus/input/devices

# Look for "Goodix" in the output
# You should see:
# N: Name="10-005d Goodix Capacitive TouchScreen"
# H: Handlers=mouse0 event5
```

**If you DON'T see Goodix:**
- Touch controller failed to initialize
- Proceed to Step 2

**If you DO see Goodix:**
- Touch hardware is working
- Problem is with Weston or Chromium configuration
- Skip to [Weston Configuration](#weston-configuration)

### Step 2: Check I2C Communication

```bash
# Install i2c-tools if not present
sudo apt install -y i2c-tools

# Scan I2C bus 10 (where touch controller lives)
sudo i2cdetect -y 10

# Expected output:
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:                         -- -- -- -- -- -- -- --
# ...
# 40: -- -- -- -- -- UU -- -- -- -- -- -- -- -- -- --
# ...
```

**Look for device at address 0x5d (shows as "UU" if driver is loaded)**

**If device is NOT visible:**
- Hardware connection problem
- Check ribbon cable to display
- Display may be faulty

**If device IS visible but driver failed:**
- Run the initialization script (see [Automated Fix](#automated-fix))

### Step 3: Check Kernel Messages

```bash
# View kernel messages related to touch
dmesg | grep -i 'goodix\|touch'

# Common errors:
# "I2C communication failure: -121" → Timing issue (use our fix)
# "supply VDDIO not found" → Normal, uses dummy regulator
# "ID 911, version: 1060" → SUCCESS! Controller initialized
```

### Step 4: Manually Initialize Touch Controller

```bash
# Unbind the driver
echo '10-005d' | sudo tee /sys/bus/i2c/drivers/Goodix-TS/unbind

# Wait 2 seconds
sleep 2

# Rebind the driver
echo '10-005d' | sudo tee /sys/bus/i2c/drivers/Goodix-TS/bind

# Wait for initialization
sleep 3

# Check if it worked
dmesg | tail -10

# Look for: "input: 10-005d Goodix Capacitive TouchScreen as /devices/..."
```

### Step 5: Check Weston Recognizes Touch

```bash
# View Weston logs
sudo journalctl -u kiosk.service --no-pager | grep -i 'touch\|event5'

# Expected output:
# "device is a touch device"
# "Touchscreen - 10-005d Goodix Capacitive TouchScreen"
# "libinput: configuring device"
# "associating input device event5 with output DSI-1"
```

**If Weston doesn't see the touch device:**
- Restart kiosk service: `sudo systemctl restart kiosk.service`
- Check user is in `input` group: `groups rege`

---

## Verification Steps

### 1. Verify Touch Device Files Exist

```bash
# Check for input event
ls -la /dev/input/event*

# Should show event5 (or similar)
crw-rw---- 1 root input 13, 69 Jan 28 22:38 event5
```

### 2. Test Touch Events Directly

```bash
# Install evtest if not present
sudo apt install -y evtest

# Test touch input
sudo evtest /dev/input/event5

# Touch the screen - you should see:
# Event: time 1234.567890, type 3 (EV_ABS), code 0 (ABS_X), value 123
# Event: time 1234.567890, type 3 (EV_ABS), code 1 (ABS_Y), value 456
# Event: time 1234.567890, -------------- SYN_REPORT ------------

# Press Ctrl+C to exit
```

### 3. Verify Weston Is Using Touch

```bash
# Check running processes
ps aux | grep weston

# Restart kiosk and watch logs
sudo systemctl restart kiosk.service
sudo journalctl -u kiosk.service -f

# Look for "device is a touch device" message
```

### 4. Test in Browser

Once kiosk is running:
1. Touch the screen
2. Touch should register as mouse clicks
3. Buttons should respond
4. UI elements should highlight/activate

---

## Common Issues

### Issue 1: Touch Works After Manual Init, But Not After Reboot

**Problem**: You run the init script manually and touch works, but after reboot it fails again.

**Solution**: The `touchscreen-init.service` isn't enabled or isn't running before kiosk.

```bash
# Check service status
systemctl status touchscreen-init.service

# If not enabled:
sudo systemctl enable touchscreen-init.service

# Check service dependencies
systemctl list-dependencies kiosk.service

# touchscreen-init.service should appear BEFORE kiosk.service
```

### Issue 2: Touch Coordinates Are Inverted or Rotated

**Problem**: Touch registers but at wrong coordinates (e.g., touching top-left registers bottom-right).

**Cause**: Display rotation doesn't match touch rotation.

**Solution**: The touch coordinates need to be transformed to match display rotation.

```bash
# Edit Weston config
sudo nano /etc/xdg/weston/weston.ini

# Add touch transformation under [output] section:
[output]
name=DSI-1
transform=rotate-90

# For portrait displays rotated to landscape:
# - If image is correct but touch is wrong, try different transform values
# - Options: rotate-90, rotate-180, rotate-270, normal

# Restart kiosk
sudo systemctl restart kiosk.service
```

### Issue 3: Touch Works But Chromium Doesn't Respond

**Problem**: Touch events reach Weston but Chromium doesn't react.

**Solution**: Ensure Chromium has touch events enabled.

```bash
# Check kiosk service has touch flag
sudo systemctl cat kiosk.service | grep touch-events

# Should show: --touch-events=enabled

# If missing, edit service:
sudo nano /etc/systemd/system/kiosk.service

# Add to Chromium flags:
    --touch-events=enabled \

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart kiosk.service
```

### Issue 4: "Error -121" Persists After Fix

**Problem**: Touch controller still shows I2C error -121 even after applying fix.

**Possible causes**:
1. Hardware connection issue (loose ribbon cable)
2. Display firmware issue
3. I2C bus speed too fast

**Solutions**:

```bash
# 1. Check cable connection
# Power off Pi, reseat DSI ribbon cable on both ends, power on

# 2. Try reducing I2C speed
sudo nano /boot/firmware/config.txt

# Add:
dtparam=i2c_arm_baudrate=50000

# Reboot
sudo reboot

# 3. Check for firmware updates
sudo rpi-update
```

### Issue 5: Multiple Touch Devices Conflict

**Problem**: Multiple touch/pointer devices causing confusion.

**Solution**: Identify and configure correct device.

```bash
# List all input devices with details
cat /proc/bus/input/devices

# Disable unwanted devices in Weston config
sudo nano /etc/xdg/weston/weston.ini

# Add section to exclude devices:
[libinput]
# Disable HDMI CEC remote as pointer
enable-tap=false

# Or create udev rule to ignore specific devices
sudo nano /etc/udev/rules.d/99-ignore-input.rules

# Add:
SUBSYSTEM=="input", ATTRS{name}=="vc4-hdmi-0", ENV{ID_INPUT_MOUSE}="0"
```

---

## Weston Configuration

If touch device exists but Weston doesn't use it properly:

```bash
# Check Weston config
cat /etc/xdg/weston/weston.ini

# Minimal working config:
[core]
idle-time=0

[output]
name=DSI-1
transform=rotate-90

[libinput]
enable-tap=true
tap-and-drag=true

# Restart after changes
sudo systemctl restart kiosk.service
```

---

## Hardware-Specific Notes

### Official Raspberry Pi 7" Touchscreen

- **Touch Controller**: FT5406 (different from Goodix)
- **I2C Address**: Built into display, auto-detected
- **Usually works**: Doesn't need initialization fix
- **If not working**: Check `/dev/input/event*` for touch device

### Waveshare 7" DSI Display

- **Touch Controller**: Goodix GT911
- **I2C Address**: 0x5d (10-005d)
- **Needs fix**: Yes, use touchscreen-init.service
- **Common issue**: I2C timing on Pi 5

### Generic DSI Displays

- **Varies by manufacturer**
- **Check dmesg**: `dmesg | grep -i touch`
- **Identify controller**: Run `sudo i2cdetect -y 10`
- **May need**: Custom device tree overlay

---

## Advanced Debugging

### Enable Weston Debug Logging

```bash
# Edit kiosk service
sudo nano /etc/systemd/system/kiosk.service

# Add environment variable:
Environment=WESTON_LOG_SCOPE=input,libinput

# Restart and view logs
sudo systemctl restart kiosk.service
sudo journalctl -u kiosk.service -f

# You'll see detailed input events
```

### Trace Touch Events with libinput

```bash
# Stop kiosk temporarily
sudo systemctl stop kiosk.service

# Run libinput debug tool
sudo libinput debug-events --device /dev/input/event5

# Touch the screen - you'll see real-time events

# Stop with Ctrl+C, restart kiosk
sudo systemctl start kiosk.service
```

### Check Chromium Touch Support

```bash
# View Chromium logs
sudo journalctl -u kiosk.service | grep -i chromium | grep -i touch

# Should show touch events being processed
```

---

## Checklist for New Kiosk Setup

When setting up a new kiosk with DSI touchscreen:

- [ ] Run Ansible playbook (includes touch fix automatically)
- [ ] Verify `touchscreen-init.service` is enabled
- [ ] Reboot Pi
- [ ] Check `dmesg | grep Goodix` shows successful initialization
- [ ] Verify `/dev/input/event5` exists
- [ ] Check Weston logs show "device is a touch device"
- [ ] Test touch by tapping buttons in the app
- [ ] If touch coordinates are wrong, adjust `transform` in `weston.ini`

---

## Quick Reference Commands

```bash
# Check touch device
cat /proc/bus/input/devices | grep -i goodix

# Scan I2C bus
sudo i2cdetect -y 10

# Check kernel messages
dmesg | grep -i goodix

# Manually initialize touch
sudo /usr/local/bin/init-touchscreen.sh

# View Weston logs
sudo journalctl -u kiosk.service | grep -i touch

# Test touch events
sudo evtest /dev/input/event5

# Restart kiosk
sudo systemctl restart kiosk.service

# Check service status
systemctl status touchscreen-init.service
systemctl status kiosk.service
```

---

## Getting Help

If touch still doesn't work after following this guide:

1. Collect diagnostic information:
```bash
# Save to file
{
  echo "=== System Info ==="
  uname -a
  cat /etc/os-release
  
  echo "=== Input Devices ==="
  cat /proc/bus/input/devices
  
  echo "=== I2C Scan ==="
  sudo i2cdetect -y 10
  
  echo "=== Kernel Messages ==="
  dmesg | grep -i 'goodix\|touch'
  
  echo "=== Weston Logs ==="
  sudo journalctl -u kiosk.service --no-pager -n 100 | grep -i touch
  
  echo "=== Services Status ==="
  systemctl status touchscreen-init.service
  systemctl status kiosk.service
} > ~/touch-debug.txt

# View the file
cat ~/touch-debug.txt
```

2. Share the diagnostic output with your support team

3. Include display model/manufacturer information

---

**Last Updated**: 2024-01-28  
**Applies To**: Raspberry Pi 5, DSI Displays with Goodix Touch Controllers  
**Tested With**: Waveshare 7" DSI Display, Pi OS Bookworm/Trixie