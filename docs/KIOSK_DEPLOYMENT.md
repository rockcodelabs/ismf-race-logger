# Raspberry Pi Kiosk Deployment Guide

**Complete guide for deploying ISMF Race Logger in kiosk mode on Raspberry Pi with 7" Touch Display 2**

**Version:** 3.0  
**Last Updated:** 2025-01-29  
**Display Resolution:** 1280×720 (landscape mode)

---

## Table of Contents

1. [Overview](#overview)
2. [Hardware Requirements](#hardware-requirements)
3. [Quick Start with Ansible](#quick-start-with-ansible)
4. [Manual Setup](#manual-setup)
5. [Configuration](#configuration)
6. [Deployment & Updates](#deployment--updates)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Security](#security)

---

## Overview

This guide covers deploying the ISMF Race Logger as a kiosk on Raspberry Pi 5 with the official 7" Touch Display 2.

### What is Kiosk Mode?

A locked-down system that:
- ✅ Boots directly to the app (no desktop)
- ✅ Runs full-screen browser (no navigation bars)
- ✅ Auto-starts on boot and recovers from crashes
- ✅ Prevents screensaver/sleep
- ✅ Hides mouse cursor (appears on touch)
- ✅ Supports touch input with virtual keyboard
- ✅ Restricts access to OS

### Architecture

```
┌─────────────────────────────────────────┐
│  Raspberry Pi OS (Wayland/Weston)       │
│  ├── Weston Compositor                  │
│  ├── Chromium (kiosk mode)             │
│  │   └── ISMF Race Logger Web App      │
│  │       ├── Touch-optimized UI        │
│  │       └── Virtual Keyboard          │
│  └── Rails/Puma (via Docker/Kamal)     │
└─────────────────────────────────────────┘
```

### Use Cases

- **Race Venues:** Referee incident reporting stations
- **Timing Areas:** Official use only, no OS access
- **Remote Locations:** Offline-capable with sync when online
- **Training:** Controlled environment for staff training

---

## Hardware Requirements

### Minimum Specifications

| Component | Requirement | Notes |
|-----------|-------------|-------|
| **Computer** | Raspberry Pi 5 (2GB RAM minimum) | 4GB recommended |
| **Display** | Official 7" Touch Display 2 | 1280×720 native (landscape) |
| **Storage** | 32GB microSD (Class 10+) | 64GB recommended |
| **Power** | Official 5V 3A USB-C supply | Essential for stability |
| **Case** | Optional but recommended | Protects hardware at venues |
| **Network** | WiFi or Ethernet | Ethernet preferred for reliability |

### Optional Accessories

- **Cooling fan** - Recommended for continuous operation
- **USB keyboard** - For initial setup only
- **Ethernet cable** - More reliable than WiFi at venues
- **USB flash drive** - For backups and logs

### Display Specifications

- **Model:** Raspberry Pi Touch Display 2
- **Native Resolution:** 720×1280 (portrait)
- **Configured Resolution:** 1280×720 (landscape, rotated 90°)
- **Touch:** 10-point capacitive multi-touch
- **Connection:** DSI ribbon cable + power

---

## Quick Start with Ansible

**Recommended method for production deployment.**

### Prerequisites

On your Mac/Linux machine:

```bash
# Install Ansible
brew install ansible  # macOS
# or
sudo apt install ansible  # Linux

# Clone repository
git clone https://github.com/your-org/ismf-race-logger.git
cd ismf-race-logger
```

### Step 1: Prepare Raspberry Pi

1. **Flash Raspberry Pi OS:**
   - Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Choose: **Raspberry Pi OS (64-bit)** with Desktop
   - Configure:
     - Hostname: `pi5main.local` (or custom)
     - Username: `rege`
     - Password: (secure password)
     - Enable SSH
     - Configure WiFi (if using)

2. **Boot Pi and verify SSH access:**

```bash
# Test SSH connection
ssh rege@pi5main.local

# Update system
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### Step 2: Configure Inventory

Edit `ansible/inventory.yml`:

```yaml
all:
  children:
    kiosk:
      hosts:
        pi5main:
          ansible_host: pi5main.local
          ansible_user: rege
          ansible_python_interpreter: /usr/bin/python3
          
          # App configuration
          app_url: "http://pi5main.local:3005"
          
          # Display configuration
          display_rotation: 1  # 90° for landscape
          
          # Chromium flags (important!)
          chromium_flags:
            - --kiosk
            - --ozone-platform=wayland
            - --enable-features=UseOzonePlatform
            - --noerrdialogs
            - --disable-infobars
            - --disable-session-crashed-bubble
            - --disable-features=TranslateUI,VirtualKeyboard
            - --disable-sync
            - --disable-translate
            - --no-first-run
            - --incognito
            - --touch-events=enabled
            - --disable-touch-keyboard  # Disable native keyboard!
```

### Step 3: Run Ansible Playbook

```bash
# Navigate to ansible directory
cd ansible

# Run full kiosk setup
ansible-playbook -i inventory.yml setup-kiosk.yml --ask-become-pass

# Enter Pi user password when prompted
```

**What this does:**
- Installs Weston compositor (Wayland)
- Installs Chromium browser
- Configures display rotation
- Creates kiosk systemd service
- Sets up auto-login
- Configures boot behavior

### Step 4: Deploy Application

Application deployment is handled separately via Kamal (Docker):

```bash
# From project root (not ansible directory)
cd ~/ismf-race-logger

# Ensure Kamal is configured
cat .kamal/secrets
# Should contain KAMAL_REGISTRY_PASSWORD and other secrets

# Deploy to Pi
kamal deploy

# Or push to GitHub for automatic deployment
git push origin main
# GitHub Actions will deploy automatically
```

### Step 5: Verify Kiosk

Reboot the Pi:

```bash
ssh rege@pi5main.local
sudo reboot
```

**Expected behavior:**
1. Pi boots
2. Auto-login as `rege`
3. Weston starts (Wayland compositor)
4. Chromium launches in kiosk mode
5. App loads at `http://pi5main.local:3005`
6. Touch mode activates automatically
7. No desktop or taskbar visible

---

## Manual Setup

If you prefer manual configuration or Ansible fails:

### Step 1: Install Base System

```bash
# SSH to Pi
ssh rege@pi5main.local

# Update system
sudo apt update
sudo apt full-upgrade -y

# Install required packages
sudo apt install -y \
  weston \
  chromium-browser \
  unclutter \
  git \
  curl \
  wget

# Reboot
sudo reboot
```

### Step 2: Configure Display Rotation

```bash
# Edit boot config
sudo nano /boot/firmware/config.txt

# Add this line at the end:
display_rotate=1  # 90° clockwise for landscape

# Save (Ctrl+O, Enter, Ctrl+X)
sudo reboot
```

**Display rotation values:**
- `0` - Normal (portrait, 720×1280)
- `1` - 90° clockwise (landscape, 1280×720) ✅
- `2` - 180° (upside-down portrait)
- `3` - 270° clockwise (landscape, flipped)

### Step 3: Configure Auto-Login

```bash
# Enable auto-login for user 'rege'
sudo raspi-config nonint do_boot_behaviour B2

# Or manually edit:
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin rege --noclear %I $TERM
EOF
```

### Step 4: Create Kiosk Service

```bash
# Create service directory
sudo mkdir -p /usr/local/bin

# Create kiosk start script
sudo tee /usr/local/bin/start-kiosk.sh > /dev/null << 'EOF'
#!/bin/bash

# Wait for Weston to be ready
sleep 3

# Hide mouse cursor
unclutter -idle 0.1 -root &

# Wait for app to be ready
echo "Waiting for app at http://pi5main.local:3005..."
until curl -s http://pi5main.local:3005 > /dev/null; do
  sleep 2
done
echo "App is ready!"

# Start Chromium in kiosk mode
exec chromium-browser \
  --kiosk \
  --ozone-platform=wayland \
  --enable-features=UseOzonePlatform \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI,VirtualKeyboard \
  --disable-sync \
  --disable-translate \
  --no-first-run \
  --incognito \
  --touch-events=enabled \
  --disable-touch-keyboard \
  http://pi5main.local:3005
EOF

sudo chmod +x /usr/local/bin/start-kiosk.sh
```

```bash
# Create systemd service
sudo tee /etc/systemd/system/kiosk.service > /dev/null << 'EOF'
[Unit]
Description=Web Kiosk for ISMF Race Logger
After=network-online.target graphical.target
Wants=network-online.target

[Service]
Type=simple
User=rege
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WAYLAND_DISPLAY=wayland-1
ExecStartPre=/bin/sleep 5
ExecStart=/usr/local/bin/start-kiosk.sh
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service
```

### Step 5: Configure Weston

```bash
# Create Weston configuration
mkdir -p ~/.config

tee ~/.config/weston.ini > /dev/null << 'EOF'
[core]
idle-time=0

[shell]
panel-position=none
locking=false

[output]
name=DSI-1
mode=1280x720
transform=normal
EOF
```

### Step 6: Setup Auto-Start Weston

```bash
# Add to bash profile
tee -a ~/.bash_profile > /dev/null << 'EOF'

# Auto-start Weston on login (tty1 only)
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec weston
fi
EOF
```

### Step 7: Deploy Application

See [Deployment & Updates](#deployment--updates) section below.

---

## Configuration

### Network Configuration

#### WiFi (Venues with WiFi)

```bash
# Configure WiFi
sudo raspi-config
# Choose: System Options → Wireless LAN
# Enter SSID and password

# Or edit manually:
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Add network block:
network={
  ssid="VenueWiFi"
  psk="password123"
  priority=10
}

# Restart WiFi
sudo systemctl restart wpa_supplicant
```

#### Ethernet (Recommended)

**Static IP (if required):**

```bash
sudo nano /etc/dhcpcd.conf

# Add at end:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4

# Save and restart
sudo systemctl restart dhcpcd
```

#### Multiple Networks (Failover)

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Primary network
network={
  ssid="PrimaryWiFi"
  psk="password1"
  priority=10
}

# Backup network
network={
  ssid="BackupWiFi"
  psk="password2"
  priority=5
}

# Mobile hotspot (emergency)
network={
  ssid="iPhone"
  psk="password3"
  priority=1
}
```

### Touch Screen Calibration

Usually not needed, but if touch is inaccurate:

```bash
# Install calibration tool
sudo apt install -y xinput-calibrator

# Run calibration
DISPLAY=:0 xinput_calibrator

# Follow on-screen instructions
# Copy output to new file:
sudo nano /etc/X11/xorg.conf.d/99-calibration.conf
```

### Screen Brightness

```bash
# Check current brightness
cat /sys/class/backlight/*/brightness

# Set brightness (0-255)
echo 200 | sudo tee /sys/class/backlight/*/brightness

# Make permanent: add to /etc/rc.local
sudo nano /etc/rc.local
# Add before "exit 0":
echo 200 > /sys/class/backlight/*/brightness
```

### Disable Screen Blanking

Already handled in Weston config (`idle-time=0`), but if issues persist:

```bash
# Edit boot config
sudo nano /boot/firmware/config.txt

# Add:
hdmi_blanking=1
```

---

## Deployment & Updates

### Initial Deployment

Application deployment uses Kamal (Docker-based):

```bash
# On your Mac (not on Pi)
cd ismf-race-logger

# Ensure secrets are configured
cat .kamal/secrets
# Should contain:
#   KAMAL_REGISTRY_PASSWORD=...
#   RAILS_MASTER_KEY=...
#   POSTGRES_PASSWORD=...

# Deploy for first time
kamal setup

# This will:
# 1. Install Docker on Pi
# 2. Pull application image
# 3. Create database
# 4. Start containers
# 5. Run migrations
```

### Updates via GitHub Actions (Recommended)

**Automatic deployment on push to main:**

```bash
# Make changes locally
git add .
git commit -m "Feature: Add new functionality"
git push origin main

# GitHub Actions automatically:
# 1. Runs tests
# 2. Builds Docker image
# 3. Pushes to registry
# 4. Deploys to Pi via Kamal
# 5. Restarts containers (zero-downtime)

# Monitor progress:
# https://github.com/your-org/ismf-race-logger/actions
```

**Wait 3-5 minutes for deployment to complete.**

### Manual Updates via Kamal

```bash
# On your Mac
cd ismf-race-logger

# Pull latest code
git pull origin main

# Deploy
kamal deploy

# This does zero-downtime deployment:
# 1. Builds new image
# 2. Starts new container
# 3. Health checks pass
# 4. Stops old container
```

### Update Kiosk Configuration Only

If you only need to update kiosk settings (not app code):

```bash
# Using Ansible
cd ansible
ansible-playbook -i inventory.yml update-kiosk-url.yml

# Or manually
ssh rege@pi5main.local
sudo systemctl restart kiosk.service
```

### Database Migrations

Handled automatically by Kamal, but manual process:

```bash
# SSH to Pi
ssh rege@pi5main.local

# Run migrations via Kamal
cd /path/to/app
kamal app exec 'bin/rails db:migrate'

# Or via Docker directly
docker exec ismf-race-logger-web-latest bin/rails db:migrate
```

---

## Monitoring & Maintenance

### Check System Status

```bash
# SSH to Pi
ssh rege@pi5main.local

# Check kiosk service
sudo systemctl status kiosk.service

# Check application service
docker ps

# Check logs
sudo journalctl -u kiosk.service -f
```

### View Application Logs

```bash
# Via Kamal (from Mac)
kamal app logs -f

# Or SSH to Pi
ssh rege@pi5main.local
docker logs -f ismf-race-logger-web-latest
```

### Check Resource Usage

```bash
# Memory
free -h
# Chromium typically uses 300-500MB

# CPU
top
# Chromium should be <50% when idle

# Disk
df -h
# App + system should be <10GB

# Temperature
vcgencmd measure_temp
# Should be <60°C (with fan)
```

### Browser Cache Management

Clear if app behaves strangely:

```bash
ssh rege@pi5main.local

# Stop kiosk
sudo systemctl stop kiosk.service

# Clear Chromium cache
rm -rf ~/.config/chromium/Default/Cache/*
rm -rf ~/.config/chromium/Default/Cookies*
rm -rf ~/.config/chromium/Default/'Service Worker'/*
rm -rf ~/.config/chromium/Default/'Local Storage'/*

# Restart kiosk
sudo systemctl start kiosk.service
```

### Backup

```bash
# Backup database (from Pi)
ssh rege@pi5main.local
docker exec ismf-race-logger-db pg_dump -U postgres ismf_race_logger_production > backup_$(date +%Y%m%d).sql

# Copy to USB drive
sudo mount /dev/sda1 /mnt
cp backup_*.sql /mnt/
sudo umount /mnt

# Or copy to Mac
scp rege@pi5main.local:~/backup_*.sql ./backups/
```

### Auto-Backup (Cron)

```bash
# SSH to Pi
ssh rege@pi5main.local

# Create backup script
tee ~/backup.sh > /dev/null << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups
mkdir -p $BACKUP_DIR

# Backup database
docker exec ismf-race-logger-db pg_dump -U postgres ismf_race_logger_production > $BACKUP_DIR/db_$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "db_*.sql" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x ~/backup.sh

# Schedule daily backup at 3 AM
(crontab -l 2>/dev/null; echo "0 3 * * * ~/backup.sh") | crontab -
```

---

## Troubleshooting

### Kiosk Doesn't Start

**Symptoms:**
- Black screen after boot
- Kiosk service fails
- Chromium doesn't launch

**Solutions:**

```bash
# Check service status
sudo systemctl status kiosk.service

# Check logs
sudo journalctl -u kiosk.service -n 50

# Common issues:

# 1. Weston not running
ps aux | grep weston
# If not running: check ~/.bash_profile

# 2. App not accessible
curl http://pi5main.local:3005
# If fails: check Docker containers

# 3. Chromium crash
rm -rf ~/.config/chromium/Default/
sudo systemctl restart kiosk.service
```

### Touch Not Working

**Symptoms:**
- Can't interact with display
- Touch events not registered

**Solutions:**

```bash
# Check if touch device exists
ls /dev/input/event*

# Check if touch events are working
evtest /dev/input/event0
# Touch screen and see if events appear

# Reboot (often fixes touch issues)
sudo reboot
```

### App Not Loading

**Symptoms:**
- Blank page or error message
- "Cannot connect" error

**Solutions:**

```bash
# Check if app is running
docker ps

# Check app logs
docker logs ismf-race-logger-web-latest

# Check network
ping pi5main.local

# Restart app
kamal app restart

# Or restart Docker
sudo systemctl restart docker
```

### Native Keyboard Appears

**Symptoms:**
- Both native and custom keyboard show
- Keyboards overlap

**Solution:**

```bash
# Verify Chromium flags
ps aux | grep chromium | grep -o '\-\-[^ ]*keyboard[^ ]*'

# Should see:
#   --disable-touch-keyboard
#   --disable-features=TranslateUI,VirtualKeyboard

# If missing, check kiosk service:
sudo systemctl cat kiosk.service | grep chromium

# Update flags if needed:
sudo nano /usr/local/bin/start-kiosk.sh
# Ensure --disable-touch-keyboard is present

# Restart
sudo systemctl restart kiosk.service
```

### Performance Issues

**Symptoms:**
- Slow page loads
- Laggy touch response
- High CPU usage

**Solutions:**

```bash
# Check temperature
vcgencmd measure_temp
# If >70°C: add cooling fan

# Check memory
free -h
# If <100MB free: add swap or reduce Chromium flags

# Reduce Chromium features
# Edit /usr/local/bin/start-kiosk.sh
# Add:
#   --disable-gpu
#   --disable-software-rasterizer

# Clear cache
rm -rf ~/.config/chromium/Default/Cache/*
```

### Cookie/Touch Detection Issues

**Symptoms:**
- Desktop mode shows instead of touch
- Need to manually add `?touch=1`

**Solution:**

```bash
# Clear cookies
rm -rf ~/.config/chromium/Default/Cookies*

# Check touch detection logs
sudo journalctl -u kiosk.service | grep -i touch

# Should see:
#   "📱 Touch detection controller connected"
#   "✅ Pi touch display detected!"

# If not, check screen resolution:
# Should be 1280×720 for auto-detection
```

### Emergency Access

**If kiosk is stuck:**

```bash
# Switch to TTY2 (physical keyboard required)
Press: Ctrl + Alt + F2

# Login as: rege
# Stop kiosk
sudo systemctl stop kiosk.service

# Fix issue, then restart
sudo systemctl start kiosk.service

# Return to kiosk
Ctrl + Alt + F1

# Or reboot
sudo reboot
```

---

## Security

### Network Security

```bash
# Install firewall
sudo apt install -y ufw

# Default deny
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from local network only
sudo ufw allow from 192.168.1.0/24 to any port 22

# Allow HTTP from local network
sudo ufw allow from 192.168.1.0/24 to any port 3005

# Enable firewall
sudo ufw enable
```

### Physical Security

- Mount Pi in locked case
- Use tamper-evident seals
- Keep USB keyboard disconnected at venue
- Use Kensington lock (if case supports)

### Disable Unused Services

```bash
# Disable Bluetooth
sudo systemctl disable bluetooth

# Disable Avahi (mDNS)
sudo systemctl disable avahi-daemon

# Disable unnecessary services
sudo systemctl disable cups  # Printing
sudo systemctl disable ModemManager
```

### Update Policy

- **OS Updates:** Monthly (off-season)
- **App Updates:** As needed via GitHub Actions
- **Security Patches:** Immediately

```bash
# Update OS (SSH or emergency access)
ssh rege@pi5main.local
sudo apt update && sudo apt upgrade -y
sudo reboot
```

---

## Production Checklist

Before deploying to venue:

### Hardware
- [ ] Pi 5 with 7" Touch Display 2
- [ ] Adequate cooling (fan or heatsinks)
- [ ] Reliable power supply (5V 3A official)
- [ ] Network connectivity (Ethernet preferred)
- [ ] Case with mounting hardware
- [ ] Backup power (UPS if available)

### Software
- [ ] Latest Raspberry Pi OS installed
- [ ] Kiosk service configured and tested
- [ ] App deployed and running
- [ ] Touch mode auto-activates
- [ ] Virtual keyboard works
- [ ] Auto-start on boot verified
- [ ] Browser cache cleared
- [ ] Offline mode tested

### Configuration
- [ ] Display rotated correctly (1280×720)
- [ ] Network configured (WiFi or Ethernet)
- [ ] SSH access enabled for remote support
- [ ] Firewall configured
- [ ] Auto-login configured
- [ ] Screen doesn't sleep

### Testing
- [ ] Cold boot test (power off, power on)
- [ ] Touch responsiveness verified
- [ ] Form submission works
- [ ] Data syncs when online
- [ ] Works offline
- [ ] No errors in logs for 24 hours
- [ ] Emergency access tested (Ctrl+Alt+F2)

### Documentation
- [ ] Network credentials documented
- [ ] SSH access documented
- [ ] Venue contact information
- [ ] Troubleshooting guide printed
- [ ] Backup Pi available (if critical)

---

## Appendix

### Useful Commands

```bash
# Kiosk Management
sudo systemctl status kiosk.service      # Check status
sudo systemctl restart kiosk.service     # Restart kiosk
sudo systemctl stop kiosk.service        # Stop kiosk
sudo journalctl -u kiosk.service -f      # View logs

# Application Management
docker ps                                # List containers
docker logs -f container-name            # View logs
kamal app restart                        # Restart app (from Mac)

# System Management
sudo reboot                              # Reboot Pi
sudo shutdown -h now                     # Shutdown Pi
free -h                                  # Memory usage
df -h                                    # Disk usage
top                                      # CPU usage
vcgencmd measure_temp                    # Temperature

# Network
ip a                                     # IP addresses
ping 8.8.8.8                            # Internet connectivity
sudo systemctl restart dhcpcd            # Restart network

# Debugging
ps aux | grep chromium                   # Chromium process
ps aux | grep weston                     # Weston process
curl http://pi5main.local:3005          # Test app
```

### Reference Documentation

- **Touch Display:** [TOUCH_DISPLAY.md](TOUCH_DISPLAY.md)
- **Ansible Playbooks:** `ansible/setup-kiosk.yml`
- **Kamal Deployment:** `.kamal/deploy.yml`
- **GitHub Actions:** `.github/workflows/deploy.yml`

### Support

For issues or questions:
- **GitHub Issues:** https://github.com/your-org/ismf-race-logger/issues
- **Email:** tech-support@ismf.org
- **Raspberry Pi Forum:** https://forums.raspberrypi.com

---

**Document Version:** 3.0  
**Last Updated:** 2025-01-29  
**Next Review:** 2025-03-01