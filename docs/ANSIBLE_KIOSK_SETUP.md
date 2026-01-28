# Ansible Kiosk Setup Guide

**Automated Raspberry Pi 5 Kiosk Configuration for ISMF Race Logger**

This guide explains how to use Ansible to automatically configure any Raspberry Pi 5 as a dedicated kiosk for the ISMF Race Logger application.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Playbooks Reference](#playbooks-reference)
- [Configuration Options](#configuration-options)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

---

## Overview

The Ansible automation handles:

- System updates and package installation
- Desktop environment removal (boot to console)
- Weston compositor configuration with display rotation
- Chromium browser in kiosk mode
- Systemd service management
- Boot optimization
- Touch input configuration
- Automatic recovery on crashes

**Result**: A production-ready kiosk that boots in 3-6 seconds directly to your web application.

---

## Prerequisites

### Control Machine (Your Computer)

You need a machine (Mac, Linux, or WSL on Windows) with:

1. **Python 3.8+**
   ```bash
   python3 --version
   ```

2. **Ansible 8.0+**
   ```bash
   # Install via pip
   pip3 install ansible

   # Or on macOS via Homebrew
   brew install ansible

   # Verify installation
   ansible --version
   ```

3. **SSH access** to your Raspberry Pi(s)

### Target Raspberry Pi(s)

Each Raspberry Pi must have:

1. **Raspberry Pi OS** (Bookworm or Trixie, 64-bit recommended)
2. **SSH enabled**
   ```bash
   # Enable via raspi-config
   sudo raspi-config
   # Navigate to: Interface Options → SSH → Enable
   ```

3. **User account with sudo privileges** (default `pi` or custom user)

4. **Network connectivity** (WiFi or Ethernet)

5. **SSH key authentication configured** (recommended):
   ```bash
   # From your control machine
   ssh-copy-id rege@pi5cam.local
   ```

---

## Quick Start

### 1. Install Ansible Dependencies

```bash
cd ansible
pip3 install -r requirements.txt
```

### 2. Create Your Inventory

```bash
# Copy the example inventory
cp inventory.example.yml inventory.yml

# Edit with your Pi's details
nano inventory.yml
```

**Minimal inventory.yml:**
```yaml
all:
  children:
    kiosks:
      hosts:
        pi5cam:
          ansible_host: pi5cam.local
          kiosk_url: http://192.168.1.233:3005
          display_rotation: rotate-90
      vars:
        ansible_user: rege
```

### 3. Test Connection

```bash
ansible kiosks -i inventory.yml -m ping
```

Expected output:
```
pi5cam | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 4. Run the Setup Playbook

```bash
ansible-playbook -i inventory.yml setup-kiosk.yml
```

This will take 5-15 minutes depending on your Pi's current state and network speed.

### 5. Reboot the Pi

```bash
# Using Ansible
ansible-playbook -i inventory.yml reboot-kiosks.yml

# Or manually via SSH
ssh rege@pi5cam.local "sudo reboot"
```

### 6. Verify

After reboot (30-60 seconds), the Pi should display your application in full-screen kiosk mode.

---

## Detailed Setup

### Step 1: Prepare Your Control Machine

#### Install Ansible

**On macOS:**
```bash
brew install ansible
```

**On Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y ansible
```

**On any system with Python:**
```bash
pip3 install --user ansible
# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Install Python Dependencies

```bash
cd ismf-race-logger/ansible
pip3 install -r requirements.txt
```

#### Verify Installation

```bash
ansible --version
# Should show: ansible [core 2.15.x] or higher
```

### Step 2: Configure SSH Access

#### Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Press Enter to accept defaults
```

#### Copy SSH Key to Pi

```bash
# Replace 'rege' with your Pi's username
# Replace 'pi5cam.local' with your Pi's hostname or IP
ssh-copy-id rege@pi5cam.local

# Test connection
ssh rege@pi5cam.local "echo 'SSH working!'"
```

#### Configure SSH Config (Optional but Recommended)

Edit `~/.ssh/config`:
```
Host pi5cam
    HostName pi5cam.local
    User rege
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Now you can connect with just: `ssh pi5cam`

### Step 3: Create Inventory File

The inventory defines which Pis to configure and how.

```bash
cd ismf-race-logger/ansible
cp inventory.example.yml inventory.yml
nano inventory.yml
```

#### Single Kiosk Example

```yaml
all:
  children:
    kiosks:
      hosts:
        pi5cam:
          ansible_host: pi5cam.local
          kiosk_url: http://192.168.1.233:3005
          display_rotation: rotate-90
      vars:
        ansible_user: rege
        ansible_python_interpreter: /usr/bin/python3
```

#### Multiple Kiosks Example

```yaml
all:
  children:
    kiosks:
      hosts:
        # Development kiosk
        pi5cam:
          ansible_host: pi5cam.local
          kiosk_url: http://192.168.1.233:3005
          display_rotation: rotate-90
        
        # Production kiosk at race venue
        pi5kiosk-production:
          ansible_host: 192.168.10.100
          kiosk_url: https://race-logger.example.com
          display_rotation: normal
        
        # Backup kiosk
        pi5kiosk-backup:
          ansible_host: 192.168.10.101
          kiosk_url: https://race-logger.example.com
          display_rotation: rotate-90
      
      vars:
        ansible_user: rege
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
        ansible_become_method: sudo
```

### Step 4: Test Ansible Connection

```bash
# Test connection to all kiosks
ansible kiosks -i inventory.yml -m ping

# Test connection to specific kiosk
ansible pi5cam -i inventory.yml -m ping

# Run a test command
ansible kiosks -i inventory.yml -a "uname -a"
```

### Step 5: Run Setup Playbook

#### Dry Run (Check Mode)

```bash
# See what would change without making changes
ansible-playbook -i inventory.yml setup-kiosk.yml --check --diff
```

#### Full Setup

```bash
# Set up all kiosks
ansible-playbook -i inventory.yml setup-kiosk.yml

# Set up specific kiosk
ansible-playbook -i inventory.yml setup-kiosk.yml --limit pi5cam

# With verbose output (useful for troubleshooting)
ansible-playbook -i inventory.yml setup-kiosk.yml -v
# Or very verbose: -vv, -vvv, -vvvv
```

#### What the Playbook Does

The setup playbook executes these phases:

1. **System Update**: Updates all packages to latest versions
2. **Boot Target**: Sets systemd to multi-user (no desktop)
3. **Package Installation**: Installs Weston, Chromium, seatd, etc.
4. **Seat Management**: Configures seatd for DRM access
5. **User Configuration**: Adds user to required groups
6. **Desktop Removal**: Disables any auto-starting desktop environments
7. **Weston Configuration**: Deploys Weston config with display rotation
8. **Systemd Service**: Creates and enables kiosk.service
9. **Boot Optimization**: Optimizes kernel parameters and GPU memory
10. **Network Configuration**: Ensures proper network wait behavior

### Step 6: Reboot and Verify

```bash
# Reboot using Ansible (recommended - includes verification)
ansible-playbook -i inventory.yml reboot-kiosks.yml

# Or reboot manually
ssh pi5cam "sudo reboot"
```

The kiosk should start automatically after reboot (30-60 seconds).

#### Verification Steps

```bash
# Check service status
ssh pi5cam "systemctl status kiosk.service"

# Check if Weston is running
ssh pi5cam "ps aux | grep weston"

# Check if Chromium is running
ssh pi5cam "ps aux | grep chromium"

# View logs
ssh pi5cam "sudo journalctl -u kiosk.service -n 50"
```

---

## Playbooks Reference

### setup-kiosk.yml

**Purpose**: Complete kiosk setup from scratch

**Usage**:
```bash
ansible-playbook -i inventory.yml setup-kiosk.yml
```

**Options**:
```bash
# Dry run
ansible-playbook -i inventory.yml setup-kiosk.yml --check

# Specific host
ansible-playbook -i inventory.yml setup-kiosk.yml --limit pi5cam

# Skip package updates (faster, use for testing)
ansible-playbook -i inventory.yml setup-kiosk.yml --skip-tags update
```

**Duration**: 5-15 minutes per host (depending on updates needed)

### reboot-kiosks.yml

**Purpose**: Safely reboot kiosks and verify they come back up correctly

**Usage**:
```bash
ansible-playbook -i inventory.yml reboot-kiosks.yml
```

**Features**:
- Pre-reboot status check
- Controlled reboot with timeout
- Wait for system to come back online
- Verify kiosk service started correctly
- Verify Weston and Chromium are running

**Options**:
```bash
# Reboot specific kiosk
ansible-playbook -i inventory.yml reboot-kiosks.yml --limit pi5cam

# Reboot with longer timeout (slow network)
ansible-playbook -i inventory.yml reboot-kiosks.yml -e "reboot_timeout=600"
```

### update-kiosk-url.yml

**Purpose**: Change the URL displayed by the kiosk without full reinstall

**Usage**:
```bash
# Update all kiosks
ansible-playbook -i inventory.yml update-kiosk-url.yml -e "new_url=https://production.example.com"

# Update specific kiosk
ansible-playbook -i inventory.yml update-kiosk-url.yml --limit pi5cam -e "new_url=http://192.168.1.100:3000"
```

**Features**:
- Validates URL is provided
- Backs up current configuration
- Updates systemd service
- Restarts kiosk
- Verifies new URL is active

**Rollback**:
```bash
# If something goes wrong, restore from backup
ssh pi5cam "sudo cp /etc/systemd/system/kiosk.service.backup.* /etc/systemd/system/kiosk.service"
ssh pi5cam "sudo systemctl daemon-reload && sudo systemctl restart kiosk.service"
```

---

## Configuration Options

### Display Rotation

Set the `display_rotation` variable in your inventory:

```yaml
display_rotation: rotate-90    # Portrait → Landscape (90° clockwise)
display_rotation: rotate-180   # Upside down
display_rotation: rotate-270   # Portrait → Landscape (90° counter-clockwise)
display_rotation: normal       # No rotation (default orientation)
```

Common use cases:
- **720x1280 portrait display**: Use `rotate-90` for landscape
- **1280x720 landscape display**: Use `normal`
- **Upside-down mounted display**: Use `rotate-180`

### Chromium Flags

Customize browser behavior by modifying `chromium_flags` in your inventory:

```yaml
chromium_flags:
  - --kiosk                          # Full-screen mode
  - --ozone-platform=wayland         # Use Wayland instead of X11
  - --enable-features=UseOzonePlatform
  - --noerrdialogs                   # Suppress error dialogs
  - --disable-infobars               # No "Chrome is being controlled" banner
  - --touch-events=enabled           # Enable touch input
  - --enable-gpu-rasterization       # Use GPU for rendering
  - --incognito                      # Private mode (no cache/cookies)
  # Add your custom flags here
```

Useful additional flags:
```yaml
  - --force-device-scale-factor=1.5  # Scale UI for high-DPI displays
  - --disk-cache-size=1              # Minimal cache (save SD card writes)
  - --disable-features=Translate     # Disable translate prompts
  - --autoplay-policy=no-user-gesture-required  # Allow auto-play videos
```

### Network Configuration

```yaml
# Wait for network before starting kiosk (default: yes)
network_wait_enabled: yes

# Network timeout in seconds (default: 120)
network_wait_timeout: 120
```

### Resource Limits

Add to your inventory to limit resource usage:

```yaml
kiosk_memory_limit: 512M    # Limit RAM usage
kiosk_cpu_quota: 80%        # Limit CPU usage to 80%
```

### Multiple URLs for Different Environments

```yaml
kiosks:
  hosts:
    pi5cam-dev:
      kiosk_url: http://192.168.1.233:3005
      environment: development
    
    pi5cam-staging:
      kiosk_url: https://staging.example.com
      environment: staging
    
    pi5cam-prod:
      kiosk_url: https://race-logger.example.com
      environment: production
```

---

## Troubleshooting

### Connection Issues

#### "Connection refused" or "Connection timed out"

```bash
# 1. Verify Pi is powered on and connected to network
ping pi5cam.local

# 2. Check if SSH is enabled on the Pi
# Connect monitor/keyboard and run:
sudo systemctl status ssh

# 3. Try connecting with password instead of key
ssh -o PreferredAuthentications=password rege@pi5cam.local

# 4. Check SSH is listening on port 22
nmap -p 22 pi5cam.local
```

#### "Permission denied (publickey)"

```bash
# 1. Copy SSH key again
ssh-copy-id rege@pi5cam.local

# 2. Or use password authentication
ansible-playbook -i inventory.yml setup-kiosk.yml --ask-pass

# 3. Verify SSH key permissions
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

#### "Host key verification failed"

```bash
# Remove old host key
ssh-keygen -R pi5cam.local

# Or disable host key checking (less secure)
export ANSIBLE_HOST_KEY_CHECKING=False
```

### Playbook Failures

#### Task fails with "UNREACHABLE"

```bash
# Increase timeout in ansible.cfg
timeout = 60

# Or in playbook command
ansible-playbook -i inventory.yml setup-kiosk.yml -e "ansible_timeout=60"
```

#### "Failed to connect to the bus" errors

These are usually harmless. The playbook uses `ignore_errors` for non-critical tasks.

#### Package installation fails

```bash
# SSH into the Pi and update manually
ssh pi5cam
sudo apt update
sudo apt upgrade -y

# Then re-run playbook
ansible-playbook -i inventory.yml setup-kiosk.yml
```

### Kiosk Runtime Issues

#### Kiosk service fails to start

```bash
# Check service status
ssh pi5cam "sudo systemctl status kiosk.service"

# View logs
ssh pi5cam "sudo journalctl -u kiosk.service -n 100"

# Common issues:
# 1. Network not available → wait longer or check network
# 2. Display not detected → check cable/connection
# 3. Permission denied → user not in video/input groups
```

#### Black screen after reboot

```bash
# 1. Check if kiosk service is running
ssh pi5cam "systemctl is-active kiosk.service"

# 2. Check Weston logs
ssh pi5cam "sudo journalctl -u kiosk.service | grep -i error"

# 3. Verify display is detected
ssh pi5cam "sudo journalctl -u kiosk.service | grep DSI"

# 4. Try restarting the service
ssh pi5cam "sudo systemctl restart kiosk.service"
```

#### Touch not working

```bash
# 1. Check input devices
ssh pi5cam "cat /proc/bus/input/devices"

# 2. Check if user is in input group
ssh pi5cam "groups rege"

# 3. Test touch events
ssh pi5cam "sudo evtest"
# Select your touch device and touch the screen
```

#### Display orientation wrong

```bash
# Update rotation in inventory.yml
display_rotation: rotate-90  # Change as needed

# Re-run playbook
ansible-playbook -i inventory.yml setup-kiosk.yml --tags weston

# Or manually edit
ssh pi5cam "sudo nano /etc/xdg/weston/weston.ini"
# Change transform value, then:
ssh pi5cam "sudo systemctl restart kiosk.service"
```

### Debug Mode

Run playbook with maximum verbosity:

```bash
ansible-playbook -i inventory.yml setup-kiosk.yml -vvvv
```

Enable Ansible debug logging:

```bash
export ANSIBLE_DEBUG=1
ansible-playbook -i inventory.yml setup-kiosk.yml
```

Check Ansible logs:

```bash
tail -f ansible/ansible.log
```

---

## Advanced Usage

### Custom Playbook Variables

Override any variable at runtime:

```bash
ansible-playbook -i inventory.yml setup-kiosk.yml \
  -e "kiosk_url=https://custom-url.com" \
  -e "display_rotation=normal" \
  -e "kiosk_user=customuser"
```

### Tags

Run only specific parts of the playbook:

```bash
# Only install packages
ansible-playbook -i inventory.yml setup-kiosk.yml --tags packages

# Only configure Weston
ansible-playbook -i inventory.yml setup-kiosk.yml --tags weston

# Skip system updates (faster)
ansible-playbook -i inventory.yml setup-kiosk.yml --skip-tags update
```

Available tags:
- `update` - System package updates
- `packages` - Package installation
- `seatd` - Seat management configuration
- `weston` - Weston compositor config
- `service` - Systemd service configuration
- `boot` - Boot optimization

### Ansible Vault for Secrets

If your kiosk URL contains credentials:

```bash
# Create encrypted file
ansible-vault create secrets.yml

# Add:
kiosk_url: "https://user:password@app.example.com"

# Use in playbook
ansible-playbook -i inventory.yml setup-kiosk.yml \
  -e @secrets.yml --ask-vault-pass
```

### Dynamic Inventory

For large deployments, use dynamic inventory:

```python
#!/usr/bin/env python3
# dynamic_inventory.py
import json

inventory = {
    "kiosks": {
        "hosts": []
    }
}

# Discover Pis on network or from database
# Add to inventory["kiosks"]["hosts"]

print(json.dumps(inventory))
```

```bash
chmod +x dynamic_inventory.py
ansible-playbook -i dynamic_inventory.py setup-kiosk.yml
```

### Monitoring and Alerts

Add monitoring playbook:

```yaml
# monitoring.yml
- hosts: kiosks
  tasks:
    - name: Check kiosk health
      systemd:
        name: kiosk.service
      register: health
    
    - name: Send alert if down
      mail:
        to: admin@example.com
        subject: "Kiosk {{ inventory_hostname }} is down"
      when: health.status.ActiveState != "active"
```

Schedule with cron:

```bash
# Run health check every 5 minutes
*/5 * * * * cd /path/to/ansible && ansible-playbook -i inventory.yml monitoring.yml
```

### Rollback to Desktop Mode

If you need to restore desktop functionality:

```bash
# Create rollback playbook or run ad-hoc:
ansible kiosks -i inventory.yml -b -m systemd -a "name=kiosk.service enabled=no state=stopped"
ansible kiosks -i inventory.yml -b -m file -a "src=/usr/lib/systemd/system/graphical.target dest=/etc/systemd/system/default.target state=link force=yes"
ansible kiosks -i inventory.yml -b -a "reboot"
```

### CI/CD Integration

Integrate kiosk deployment with GitHub Actions:

```yaml
# .github/workflows/deploy-kiosk.yml
name: Deploy Kiosk Configuration
on:
  push:
    branches: [main]
    paths:
      - 'ansible/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Ansible
        run: pip install ansible
      
      - name: Configure SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.KIOSK_SSH_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
      
      - name: Deploy to Production Kiosks
        run: |
          cd ansible
          ansible-playbook -i inventory.yml update-kiosk-url.yml \
            -e "new_url=${{ secrets.PRODUCTION_URL }}"
```

---

## Best Practices

### 1. Version Control

Always keep your inventory in version control:

```bash
cd ansible
git add inventory.yml ansible.cfg
git commit -m "Update kiosk configuration"
git push
```

Use `.gitignore` for secrets:

```
# ansible/.gitignore
secrets.yml
*.retry
ansible.log
/tmp/
```

### 2. Test Before Production

1. **Development Kiosk**: Test changes on a dev kiosk first
2. **Check Mode**: Use `--check` for dry runs
3. **Limit Flag**: Deploy to one kiosk before all: `--limit pi5cam-test`

### 3. Backups

Before major changes:

```bash
# Backup current configuration
ssh pi5cam "sudo cp /etc/systemd/system/kiosk.service /etc/systemd/system/kiosk.service.backup"
ssh pi5cam "sudo cp /etc/xdg/weston/weston.ini /etc/xdg/weston/weston.ini.backup"
```

### 4. Documentation

Document your setup:

```yaml
# In inventory.yml, add comments
pi5cam:
  ansible_host: pi5cam.local
  kiosk_url: http://192.168.1.233:3005
  display_rotation: rotate-90
  # Location: Main entrance
  # Display: 7" DSI touchscreen
  # Last updated: 2024-01-28
```

### 5. Monitoring

Set up basic monitoring:

```bash
# Create simple health check script on kiosk
ssh pi5cam "cat > /usr/local/bin/kiosk-health.sh" << 'EOF'
#!/bin/bash
systemctl is-active kiosk.service || systemctl restart kiosk.service
EOF

ssh pi5cam "chmod +x /usr/local/bin/kiosk-health.sh"

# Add to crontab
ssh pi5cam "echo '*/5 * * * * /usr/local/bin/kiosk-health.sh' | crontab -"
```

---

## Security Considerations

### SSH Keys

- Use ed25519 keys (smaller, faster, more secure than RSA)
- Protect private keys: `chmod 600 ~/.ssh/id_ed25519`
- Use different keys for different environments
- Consider using ssh-agent for key management

### Ansible Vault

Store sensitive data encrypted:

```bash
# Encrypt existing file
ansible-vault encrypt secrets.yml

# Edit encrypted file
ansible-vault edit secrets.yml

# Run with vault
ansible-playbook -i inventory.yml setup-kiosk.yml --vault-password-file ~/.vault_pass
```

### Kiosk Security

The kiosk setup:
- Runs as non-root user
- Uses incognito mode (no persistent data)
- No SSH password authentication (keys only)
- Minimal attack surface (no desktop environment)

For additional security:
- Use HTTPS URLs only
- Set up firewall rules
- Disable unused services
- Regular security updates

---

## Performance Tuning

### Faster Playbook Execution

```yaml
# In ansible.cfg
[defaults]
forks = 10              # Parallel execution
pipelining = True       # Faster SSH
gathering = explicit    # Skip fact gathering when not needed
```

### Kiosk Performance

Optimize in `inventory.yml`:

```yaml
# Reduce memory usage
chromium_flags:
  - --disk-cache-size=1
  - --media-cache-size=1
  - --aggressive-cache-discard
  - --disable-software-rasterizer

# Limit resources
kiosk_memory_limit: 512M
```

---

## Related Documentation

- [Weston Kiosk Setup (Manual)](RASPBERRY_PI_WESTON_KIOSK.md)
- [Offline Sync Strategy](OFFLINE_SYNC_STRATEGY.md)
- [Development Commands](DEV_COMMANDS.md)
- [Architecture Overview](ARCHITECTURE.md)

---

## Support and Contributing

### Getting Help

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Ansible logs: `tail -f ansible/ansible.log`
3. Check kiosk logs: `ssh pi5cam "sudo journalctl -u kiosk.service"`
4. Open an issue on GitHub with:
   - Ansible version: `ansible --version`
   - Playbook output (use `-vvv`)
   - Pi OS version: `cat /etc/os-release`

### Contributing

Improvements welcome! Areas for contribution:
- Additional playbooks (monitoring, updates, etc.)
- Support for other displays/orientations
- Performance optimizations
- Security enhancements

---

**Last Updated**: 2024-01-28  
**Ansible Version**: 8.0+  
**Target OS**: Raspberry Pi OS Bookworm/Trixie (64-bit)  
**Hardware**: Raspberry Pi 5