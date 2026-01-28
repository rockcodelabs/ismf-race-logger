# Raspberry Pi Weston Kiosk Setup

**Online-only kiosk for ISMF Race Logger with maximum performance**

## Overview

This setup provides a lightweight, fast-booting kiosk that:
- Boots directly to the web application (no desktop environment)
- Uses Weston (Wayland compositor) + Chromium for hardware acceleration
- Enables touch input
- Auto-restarts on crashes
- Waits for network before starting

## Architecture

```
Boot → systemd (multi-user.target)
         └─ kiosk.service
              └─ weston (DRM backend, kiosk shell)
                   └─ chromium (kiosk mode, touch-enabled)
                        └─ http://192.168.1.233:3005
```

## Installed Components

| Component | Purpose |
|-----------|---------|
| `weston` | Minimal Wayland compositor with kiosk shell |
| `chromium` | Web browser with GPU acceleration |
| `unclutter` | Hides mouse cursor |
| `systemd-networkd-wait-online` | Ensures network is up before kiosk starts |

## System Configuration

### Boot Target
```bash
# Set to multi-user (no desktop)
sudo systemctl set-default multi-user.target
```

### Kernel Parameters
File: `/boot/firmware/cmdline.txt`
```
... loglevel=3 vt.global_cursor_default=0
```
- `loglevel=3` — Reduce boot noise
- `vt.global_cursor_default=0` — Hide console cursor

### GPU Memory
File: `/boot/firmware/config.txt`
```
gpu_mem=256
```

### Weston Configuration
File: `/etc/xdg/weston/weston.ini`
```ini
[core]
idle-time=0
```
Disables screen blanking.

## Kiosk Service

File: `/etc/systemd/system/kiosk.service`

```ini
[Unit]
Description=Web Kiosk
After=network-online.target
Wants=network-online.target

[Service]
User=rege
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=WAYLAND_DISPLAY=wayland-0

ExecStart=/usr/bin/weston \
  --backend=drm-backend.so \
  --shell=kiosk-shell.so \
  --idle-time=0 \
  -- \
  /usr/bin/chromium \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --disable-sync \
    --disable-translate \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-backgrounding-occluded-windows \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --ignore-gpu-blocklist \
    --no-first-run \
    --incognito \
    --touch-events=enabled \
    http://192.168.1.233:3005

Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

### Service Control

```bash
# Enable (start on boot)
sudo systemctl enable kiosk.service

# Start manually
sudo systemctl start kiosk.service

# Stop
sudo systemctl stop kiosk.service

# View logs
sudo journalctl -u kiosk.service -f

# Check status
sudo systemctl status kiosk.service
```

## Chromium Flags Explained

| Flag | Purpose |
|------|---------|
| `--kiosk` | Full-screen mode, no UI chrome |
| `--noerrdialogs` | Suppress error dialogs |
| `--disable-infobars` | No "Chrome is being controlled" banner |
| `--disable-session-crashed-bubble` | No crash recovery popup |
| `--touch-events=enabled` | Enable touch input |
| `--enable-gpu-rasterization` | Use GPU for rendering |
| `--enable-zero-copy` | Optimize GPU memory transfers |
| `--ignore-gpu-blocklist` | Force GPU acceleration |
| `--incognito` | No persistent state |

## Emergency Access

### SSH Access
Always available (if network is up):
```bash
ssh rege@pi5cam.local
```

### Console Access (Physical)
1. **CTRL+ALT+F2** — Switch to TTY2
2. Login as `rege`
3. Stop kiosk: `sudo systemctl stop kiosk.service`

### Kill Chromium/Weston
```bash
pkill -9 chromium
pkill -9 weston
```

## Troubleshooting

### Kiosk doesn't start
```bash
# Check service status
sudo systemctl status kiosk.service

# View logs
sudo journalctl -u kiosk.service -n 50

# Check if Weston is running
ps aux | grep weston

# Check if Chromium is running
ps aux | grep chromium
```

### Touch not working
```bash
# List input devices
cat /proc/bus/input/devices

# Test touch events
sudo evtest /dev/input/eventX

# Check if touch is recognized
xinput list  # (if running X11/Xwayland)
```

### Network issues
```bash
# Check network status
ip addr show

# Test connectivity
ping 192.168.1.233

# Check network wait service
systemctl status systemd-networkd-wait-online.service
```

### Black screen
1. Check display is connected and powered
2. Check HDMI/DisplayPort cable
3. SSH in and check logs: `sudo journalctl -u kiosk.service`
4. Try restarting: `sudo systemctl restart kiosk.service`

### Display shows console text
- System may not have fully booted
- Weston may have failed to start (check logs)
- GPU may not be available (check `dmesg | grep drm`)

## Performance Metrics

Expected performance on Raspberry Pi 5:

| Metric | Target |
|--------|--------|
| Boot to UI | 3–6 seconds |
| Input latency | <50ms |
| RAM usage | 300–400 MB |
| GPU acceleration | Enabled |
| Touch response | Native |

## Changing the URL

Edit `/etc/systemd/system/kiosk.service` and change the URL on the last line of `ExecStart`:

```bash
sudo nano /etc/systemd/system/kiosk.service
# Change: http://192.168.1.233:3005
# To your production URL

sudo systemctl daemon-reload
sudo systemctl restart kiosk.service
```

## Reverting to Desktop

To restore the desktop environment:

```bash
# Set graphical target
sudo systemctl set-default graphical.target

# Disable kiosk
sudo systemctl disable kiosk.service

# Reboot
sudo reboot
```

## Production Deployment

For production, change the URL to your deployed application:

```bash
# Edit service
sudo nano /etc/systemd/system/kiosk.service

# Change URL to production
http://your-production-domain.com

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart kiosk.service
```

## Security Notes

- Kiosk runs as user `rege` (not root)
- Chromium runs in incognito mode (no persistent data)
- No desktop environment exposed
- SSH remains available for remote management
- Physical console access requires TTY switch (CTRL+ALT+F2)

## File Locations

| File | Purpose |
|------|---------|
| `/etc/systemd/system/kiosk.service` | Kiosk systemd unit |
| `/etc/xdg/weston/weston.ini` | Weston configuration |
| `/boot/firmware/cmdline.txt` | Kernel boot parameters |
| `/boot/firmware/config.txt` | Raspberry Pi hardware config |

## Related Documentation

- [Offline Sync Strategy](OFFLINE_SYNC_STRATEGY.md) — Full offline operation design
- [Raspberry Pi Kiosk Setup (Desktop)](RASPBERRY_PI_KIOSK_SETUP.md) — Alternative desktop-based approach
- [Dev Commands](DEV_COMMANDS.md) — Development workflow commands

---

**System Info:**
- Raspberry Pi: 5
- OS: Debian GNU/Linux 13 (trixie)
- Weston: 14.0.2
- Chromium: Latest from Debian repos
- Display: Touch-enabled HDMI display