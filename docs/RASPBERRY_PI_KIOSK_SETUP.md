# Raspberry Pi Kiosk Mode Setup Guide

**Complete guide for running ISMF Race Logger in full-screen kiosk mode on Raspberry Pi with touch display**

---

## Table of Contents

- [Overview](#overview)
- [Hardware Requirements](#hardware-requirements)
- [Operating System Setup](#operating-system-setup)
- [Install Dependencies](#install-dependencies)
- [Configure Kiosk Mode](#configure-kiosk-mode)
- [Touch Display Configuration](#touch-display-configuration)
- [Auto-Start on Boot](#auto-start-on-boot)
- [Network Configuration](#network-configuration)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

---

## Overview

This guide sets up a Raspberry Pi to run the ISMF Race Logger in **kiosk mode**:

- ✅ Auto-starts on boot
- ✅ Full-screen browser (no navigation bars)
- ✅ Touch-optimized interface
- ✅ Auto-reconnect if app crashes
- ✅ Prevents screensaver/sleep
- ✅ Hides mouse cursor
- ✅ No access to OS (locked down)

**Perfect for:** Race venue deployment where referees only interact with the app.

---

## Hardware Requirements

### Minimum Specs

- **Raspberry Pi 5** (4GB RAM recommended, 2GB minimum)
- **Official 7" Touch Display** (800x480) or compatible
- **32GB microSD card** (Class 10 or better)
- **Official Pi Power Supply** (5V 3A USB-C for Pi 5)
- **Case** (optional but recommended for venue use)

### Optional

- **Cooling fan** (for continuous operation)
- **Ethernet cable** (more reliable than WiFi at venues)
- **USB keyboard** (for initial setup only)

---

## Operating System Setup

### 1. Download Raspberry Pi OS Lite

```bash
# Download Raspberry Pi OS Lite (64-bit)
# Use Raspberry Pi Imager: https://www.raspberrypi.com/software/

# Choose:
# - Raspberry Pi OS (64-bit) with Desktop
# - Enable SSH (for remote management)
# - Set hostname: ismf-race-logger-pi
# - Configure WiFi (optional)
# - Set username: ismf / password: <secure_password>
```

### 2. First Boot

```bash
# SSH into Pi (or use keyboard/monitor)
ssh ismf@ismf-race-logger-pi.local

# Update system
sudo apt update
sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  chromium-browser \
  unclutter \
  xdotool \
  x11-xserver-utils \
  postgresql \
  postgresql-contrib \
  git \
  curl \
  nginx

# Reboot
sudo reboot
```

---

## Install Dependencies

### 1. Install Ruby 3.4.8

```bash
# Install RVM
curl -fsSL https://get.rvm.io | bash
source ~/.rvm/scripts/rvm

# Install Ruby
rvm install 3.4.8
rvm use 3.4.8 --default

# Verify
ruby -v
# => ruby 3.4.8
```

### 2. Install Rails Application

```bash
# Clone repository
cd ~
git clone https://github.com/your-org/ismf-race-logger.git
cd ismf-race-logger

# Install gems
bundle install

# Configure environment
cat > .env << EOF
SYSTEM_MODE=offline_device
RAILS_ENV=production
DATABASE_URL=postgresql://ismf:password@localhost/ismf_race_logger_pi
SYNC_SERVER_URL=https://race-logger.ismf.cloud
SECRET_KEY_BASE=$(bin/rails secret)
PORT=3000
EOF

# Setup database
sudo -u postgres psql << EOSQL
CREATE USER ismf WITH PASSWORD 'password';
CREATE DATABASE ismf_race_logger_pi OWNER ismf;
GRANT ALL PRIVILEGES ON DATABASE ismf_race_logger_pi TO ismf;
EOSQL

RAILS_ENV=production bin/rails db:create db:migrate

# Precompile assets
RAILS_ENV=production bin/rails assets:precompile
```

### 3. Setup Rails as Service

```bash
# Create systemd service
sudo tee /etc/systemd/system/race-logger.service > /dev/null << EOF
[Unit]
Description=ISMF Race Logger (Offline Device)
After=network.target postgresql.service

[Service]
Type=simple
User=ismf
WorkingDirectory=/home/ismf/ismf-race-logger
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/home/ismf/.rvm/wrappers/ruby-3.4.8/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable race-logger
sudo systemctl start race-logger

# Check status
sudo systemctl status race-logger
```

### 4. Configure Nginx (Optional)

```bash
sudo tee /etc/nginx/sites-available/race-logger > /dev/null << EOF
upstream race_logger {
  server 127.0.0.1:3000;
}

server {
  listen 80;
  server_name localhost;
  
  location / {
    proxy_pass http://race_logger;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    # WebSocket support (for live updates when online)
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF

sudo ln -sf /etc/nginx/sites-available/race-logger /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

---

## Configure Kiosk Mode

### 1. Create Kiosk Start Script

```bash
# Create kiosk script
mkdir -p ~/kiosk
tee ~/kiosk/start-kiosk.sh > /dev/null << 'EOF'
#!/bin/bash

# Disable screensaver and power management
xset s off
xset s noblank
xset -dpms

# Hide mouse cursor (will appear on touch)
unclutter -idle 0.1 -root &

# Remove Chromium crash restore prompt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

# Wait for network and Rails app to be ready
echo "Waiting for Rails app..."
until curl -s http://localhost:3000 > /dev/null; do
  sleep 2
done
echo "Rails app is ready!"

# Start Chromium in kiosk mode
chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-features=TranslateUI \
  --no-first-run \
  --disable-translate \
  --check-for-update-interval=31536000 \
  --autoplay-policy=no-user-gesture-required \
  --disable-pinch \
  --overscroll-history-navigation=0 \
  --start-fullscreen \
  --window-position=0,0 \
  --enable-features=OverlayScrollbar \
  --touch-events=enabled \
  http://localhost:3000
EOF

chmod +x ~/kiosk/start-kiosk.sh
```

### 2. Configure Auto-Login

```bash
# Enable auto-login for user 'ismf'
sudo raspi-config nonint do_boot_behaviour B4

# Or manually edit:
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ismf --noclear %I \$TERM
EOF
```

### 3. Configure X11 Auto-Start

```bash
# Create .xinitrc
tee ~/.xinitrc > /dev/null << 'EOF'
#!/bin/bash

# Start window manager (lightweight)
openbox-session &

# Start kiosk
/home/ismf/kiosk/start-kiosk.sh
EOF

chmod +x ~/.xinitrc
```

### 4. Configure .bash_profile to Start X11

```bash
# Add to .bash_profile (runs on login)
tee -a ~/.bash_profile > /dev/null << 'EOF'

# Start X11 on login (tty1 only)
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOF
```

---

## Touch Display Configuration

### 1. Rotate Display (if needed)

```bash
# Edit boot config
sudo nano /boot/firmware/config.txt

# Add one of these lines:
display_rotate=0  # Normal
display_rotate=1  # 90 degrees
display_rotate=2  # 180 degrees
display_rotate=3  # 270 degrees

# Save and reboot
sudo reboot
```

### 2. Calibrate Touch Screen

```bash
# Install calibration tool
sudo apt install -y xinput-calibrator

# Run calibration (use stylus or finger to touch targets)
DISPLAY=:0 xinput_calibrator

# Follow on-screen instructions
# Copy output to:
sudo tee /etc/X11/xorg.conf.d/99-calibration.conf
```

### 3. Optimize Touch Experience

```bash
# Create custom CSS for touch-friendly UI
tee ~/ismf-race-logger/app/assets/stylesheets/kiosk.css > /dev/null << 'EOF'
/* Kiosk Mode Overrides */
@media (max-width: 800px) {
  /* Larger touch targets */
  button, a.button, input[type="submit"] {
    min-height: 60px;
    font-size: 1.2rem;
    padding: 1rem 1.5rem;
  }
  
  /* Larger form inputs */
  input[type="text"],
  input[type="number"],
  select {
    min-height: 50px;
    font-size: 1.1rem;
  }
  
  /* Remove hover effects (no mouse) */
  * {
    -webkit-tap-highlight-color: rgba(0,0,0,0.1);
  }
  
  /* Hide scrollbars but keep scrolling */
  ::-webkit-scrollbar {
    width: 8px;
  }
  
  ::-webkit-scrollbar-thumb {
    background: rgba(0,0,0,0.3);
    border-radius: 4px;
  }
}
EOF
```

---

## Auto-Start on Boot

### Full Boot Sequence

```
1. Pi boots
2. Auto-login as 'ismf' user
3. .bash_profile runs → starts X11
4. .xinitrc runs → starts openbox + kiosk script
5. start-kiosk.sh runs → waits for Rails, launches Chromium
6. App loads in fullscreen kiosk mode
```

### Verify Auto-Start

```bash
# Reboot and test
sudo reboot

# After reboot, you should see:
# - Chromium opens automatically
# - App loads in fullscreen
# - No mouse cursor visible
# - Touch works immediately
```

---

## Network Configuration

### 1. WiFi Setup (for venues with WiFi)

```bash
# Configure WiFi
sudo raspi-config
# Choose: System Options → Wireless LAN
# Enter SSID and password

# Or edit manually:
sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null << EOF
network={
  ssid="VenueWiFi"
  psk="password123"
  priority=10
}

network={
  ssid="BackupWiFi"
  psk="backup456"
  priority=5
}
EOF

# Restart WiFi
sudo systemctl restart wpa_supplicant
```

### 2. Ethernet Setup (recommended for venues)

```bash
# Static IP (if required by venue)
sudo tee /etc/dhcpcd.conf > /dev/null << EOF
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
EOF

# Restart networking
sudo systemctl restart dhcpcd
```

### 3. Auto-Reconnect on Network Loss

```bash
# Create network monitor script
tee ~/kiosk/monitor-network.sh > /dev/null << 'EOF'
#!/bin/bash

while true; do
  if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "Network down, restarting..."
    sudo systemctl restart dhcpcd
    sleep 10
  fi
  sleep 30
done
EOF

chmod +x ~/kiosk/monitor-network.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "@reboot /home/ismf/kiosk/monitor-network.sh &") | crontab -
```

---

## Troubleshooting

### Issue: Browser Doesn't Start

```bash
# Check if X11 is running
echo $DISPLAY
# Should output: :0

# Check kiosk script logs
cat ~/.local/share/xorg/Xorg.0.log

# Manually start kiosk
startx
```

### Issue: Rails App Not Accessible

```bash
# Check Rails service
sudo systemctl status race-logger

# Check logs
journalctl -u race-logger -f

# Test manually
cd ~/ismf-race-logger
RAILS_ENV=production bin/rails server

# Access from browser
# http://localhost:3000
```

### Issue: Touch Not Working

```bash
# Check input devices
xinput list

# Test touch events
xinput test-xi2 --root

# Recalibrate
DISPLAY=:0 xinput_calibrator
```

### Issue: Screen Goes Black (Sleep)

```bash
# Verify DPMS is disabled
xset q | grep DPMS
# Should show: DPMS is Disabled

# Add to kiosk script if not working:
echo "xset s off && xset -dpms && xset s noblank" >> ~/.xinitrc
```

### Issue: App Crashes on Boot

```bash
# Add delay before starting browser
# Edit ~/kiosk/start-kiosk.sh
# Change:
until curl -s http://localhost:3000 > /dev/null; do
  sleep 5  # Increase from 2 to 5 seconds
done
```

---

## Maintenance

### Remote Access (SSH)

```bash
# Enable SSH (if not already enabled)
sudo systemctl enable ssh
sudo systemctl start ssh

# Access from another computer
ssh ismf@ismf-race-logger-pi.local

# Or by IP
ssh ismf@192.168.1.100
```

### Update Application

```bash
# SSH into Pi
cd ~/ismf-race-logger

# Pull latest code
git pull origin main

# Update dependencies
bundle install

# Run migrations
RAILS_ENV=production bin/rails db:migrate

# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Restart service
sudo systemctl restart race-logger

# Browser will auto-reload
```

### View Logs

```bash
# Rails logs
tail -f ~/ismf-race-logger/log/production.log

# System logs
sudo journalctl -u race-logger -f

# Nginx logs (if using)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Exit Kiosk Mode (Emergency)

```bash
# Press keys simultaneously:
Ctrl + Alt + F2

# This switches to TTY2 terminal
# Login and stop services:
sudo systemctl stop race-logger

# Return to kiosk:
Ctrl + Alt + F1

# Or reboot:
sudo reboot
```

### Backup Configuration

```bash
# Backup important files
mkdir -p ~/backup
cp ~/.bash_profile ~/backup/
cp ~/.xinitrc ~/backup/
cp ~/kiosk/start-kiosk.sh ~/backup/
cp ~/ismf-race-logger/.env ~/backup/

# Backup database
pg_dump ismf_race_logger_pi > ~/backup/db_backup_$(date +%Y%m%d).sql

# Copy to USB drive
sudo mount /dev/sda1 /mnt
cp -r ~/backup /mnt/
sudo umount /mnt
```

### Reset to Factory (Clean Start)

```bash
# Stop services
sudo systemctl stop race-logger

# Remove auto-start
rm ~/.bash_profile
rm ~/.xinitrc

# Re-image SD card and start over
# OR restore from backup
```

---

## Production Checklist

Before deploying to race venue:

- [ ] Rails app starts automatically on boot
- [ ] Browser loads in fullscreen kiosk mode
- [ ] Touch screen works correctly
- [ ] No mouse cursor visible (except when touched)
- [ ] Screen doesn't sleep or turn off
- [ ] App survives reboot (auto-starts)
- [ ] Network auto-connects (WiFi or Ethernet)
- [ ] SSH access works for remote support
- [ ] Sync works when online
- [ ] App works offline (create incidents, reports)
- [ ] Emergency exit works (Ctrl+Alt+F2)
- [ ] Logs are accessible
- [ ] Backup exists

---

## Advanced: Multiple Apps/Tabs

If you need to show multiple pages in tabs:

```bash
# Edit ~/kiosk/start-kiosk.sh
# Replace the chromium-browser command with:

chromium-browser \
  --kiosk \
  --app=http://localhost:3000/incidents \
  http://localhost:3000/reports \
  http://localhost:3000/races \
  # etc...
```

**Or use Chromium's tab cycling:**

```bash
# Add to kiosk script (before chromium launches):
# Create extension to cycle tabs every 30 seconds
# This is complex - see Chromium extension docs
```

---

## Security Considerations

### Lock Down Pi

```bash
# Disable unused services
sudo systemctl disable bluetooth
sudo systemctl disable avahi-daemon

# Firewall (allow only local access)
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw allow from 192.168.1.0/24 to any port 22  # SSH from local network
sudo ufw enable
```

### Physical Security

- Mount Pi in locked case
- Disable USB ports (in BIOS if possible)
- Use tamper-evident seals
- Keep keyboard/mouse disconnected at venue

---

## Support

For issues or questions:

- **Technical:** tech-support@ismf.org
- **Documentation:** [OFFLINE_SYNC_STRATEGY.md](OFFLINE_SYNC_STRATEGY.md)
- **Raspberry Pi Forum:** https://forums.raspberrypi.com

---

**Last Updated:** 2026-01-27  
**Tested On:** Raspberry Pi 5, 4GB RAM, Official 7" Display  
**OS Version:** Raspberry Pi OS (64-bit) Bookworm