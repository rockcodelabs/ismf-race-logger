#!/bin/bash
# Quick Start Script for ISMF Race Logger Kiosk Setup
# This script helps you get started with Ansible configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_header() {
    echo ""
    print_msg "$BLUE" "============================================================"
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "============================================================"
    echo ""
}

print_success() {
    print_msg "$GREEN" "✓ $1"
}

print_error() {
    print_msg "$RED" "✗ $1"
}

print_warning() {
    print_msg "$YELLOW" "⚠ $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main menu
show_menu() {
    print_header "ISMF Race Logger - Kiosk Setup Menu"
    echo "1) Check prerequisites"
    echo "2) Install Ansible dependencies"
    echo "3) Create inventory file"
    echo "4) Test connection to Pi"
    echo "5) Run kiosk setup"
    echo "6) Reboot kiosks"
    echo "7) Update kiosk URL"
    echo "8) View kiosk status"
    echo "9) View kiosk logs"
    echo "0) Exit"
    echo ""
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1) check_prerequisites ;;
        2) install_dependencies ;;
        3) create_inventory ;;
        4) test_connection ;;
        5) run_setup ;;
        6) reboot_kiosks ;;
        7) update_url ;;
        8) view_status ;;
        9) view_logs ;;
        0) exit 0 ;;
        *) print_error "Invalid option"; show_menu ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    all_good=true
    
    # Check Python
    if command_exists python3; then
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_success "Python 3 installed: $python_version"
    else
        print_error "Python 3 not found"
        all_good=false
    fi
    
    # Check pip
    if command_exists pip3; then
        print_success "pip3 installed"
    else
        print_error "pip3 not found"
        all_good=false
    fi
    
    # Check Ansible
    if command_exists ansible; then
        ansible_version=$(ansible --version | head -1)
        print_success "Ansible installed: $ansible_version"
    else
        print_warning "Ansible not found (will be installed in next step)"
    fi
    
    # Check SSH
    if command_exists ssh; then
        print_success "SSH client installed"
    else
        print_error "SSH client not found"
        all_good=false
    fi
    
    # Check for SSH key
    if [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ]; then
        print_success "SSH key found"
    else
        print_warning "No SSH key found. Generate one with: ssh-keygen -t ed25519"
    fi
    
    # Check inventory
    if [ -f inventory.yml ]; then
        print_success "Inventory file exists"
    else
        print_warning "Inventory file not found (create in step 3)"
    fi
    
    echo ""
    if [ "$all_good" = true ]; then
        print_success "All prerequisites met!"
    else
        print_error "Some prerequisites missing. Install them before proceeding."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Install dependencies
install_dependencies() {
    print_header "Installing Ansible Dependencies"
    
    if [ ! -f requirements.txt ]; then
        print_error "requirements.txt not found"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    print_msg "$BLUE" "Installing Python packages..."
    pip3 install -r requirements.txt
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Create inventory
create_inventory() {
    print_header "Create Inventory File"
    
    if [ -f inventory.yml ]; then
        print_warning "inventory.yml already exists"
        read -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            show_menu
            return
        fi
    fi
    
    echo "Let's create your inventory file..."
    echo ""
    
    read -p "Pi hostname or IP (e.g., pi5cam.local): " pi_host
    read -p "Pi username (default: rege): " pi_user
    pi_user=${pi_user:-rege}
    read -p "Kiosk URL (e.g., http://192.168.1.233:3005): " kiosk_url
    
    echo ""
    echo "Display rotation options:"
    echo "  1) rotate-90  (portrait to landscape, 90° clockwise)"
    echo "  2) rotate-180 (upside down)"
    echo "  3) rotate-270 (portrait to landscape, 90° counter-clockwise)"
    echo "  4) normal     (no rotation)"
    read -p "Select rotation (1-4, default: 1): " rotation_choice
    
    case $rotation_choice in
        2) rotation="rotate-180" ;;
        3) rotation="rotate-270" ;;
        4) rotation="normal" ;;
        *) rotation="rotate-90" ;;
    esac
    
    # Create inventory file
    cat > inventory.yml << EOF
# Ansible Inventory for ISMF Race Logger Kiosks
# Generated by quick-start.sh

all:
  children:
    kiosks:
      hosts:
        $pi_host:
          ansible_host: $pi_host
          kiosk_url: $kiosk_url
          display_rotation: $rotation
      
      vars:
        ansible_user: $pi_user
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
        ansible_become_method: sudo
        
        chromium_flags:
          - --kiosk
          - --ozone-platform=wayland
          - --enable-features=UseOzonePlatform
          - --noerrdialogs
          - --disable-infobars
          - --disable-session-crashed-bubble
          - --disable-features=TranslateUI
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
EOF
    
    print_success "Inventory file created: inventory.yml"
    echo ""
    print_msg "$BLUE" "Configuration:"
    print_msg "$BLUE" "  Host: $pi_host"
    print_msg "$BLUE" "  User: $pi_user"
    print_msg "$BLUE" "  URL: $kiosk_url"
    print_msg "$BLUE" "  Rotation: $rotation"
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Test connection
test_connection() {
    print_header "Testing Connection to Pi"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found. Create it first (option 3)"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    print_msg "$BLUE" "Testing SSH connection..."
    ansible kiosks -i inventory.yml -m ping
    
    if [ $? -eq 0 ]; then
        print_success "Connection successful!"
    else
        print_error "Connection failed"
        echo ""
        print_msg "$YELLOW" "Troubleshooting tips:"
        echo "1. Verify Pi is powered on and connected to network"
        echo "2. Check hostname/IP is correct in inventory.yml"
        echo "3. Ensure SSH is enabled on the Pi"
        echo "4. Copy SSH key: ssh-copy-id user@pi-host"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Run setup
run_setup() {
    print_header "Run Kiosk Setup"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found. Create it first (option 3)"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    print_warning "This will configure your Pi as a kiosk. It may take 5-15 minutes."
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        show_menu
        return
    fi
    
    echo ""
    print_msg "$BLUE" "Running setup playbook..."
    ansible-playbook -i inventory.yml setup-kiosk.yml
    
    if [ $? -eq 0 ]; then
        print_success "Setup completed successfully!"
        echo ""
        print_msg "$GREEN" "Next step: Reboot the Pi (option 6)"
    else
        print_error "Setup failed. Check the output above for errors."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Reboot kiosks
reboot_kiosks() {
    print_header "Reboot Kiosks"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    print_warning "This will reboot all kiosks defined in inventory.yml"
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        show_menu
        return
    fi
    
    echo ""
    ansible-playbook -i inventory.yml reboot-kiosks.yml
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Update URL
update_url() {
    print_header "Update Kiosk URL"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Enter new URL: " new_url
    
    if [ -z "$new_url" ]; then
        print_error "URL cannot be empty"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    echo ""
    print_msg "$BLUE" "Updating to: $new_url"
    ansible-playbook -i inventory.yml update-kiosk-url.yml -e "new_url=$new_url"
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# View status
view_status() {
    print_header "View Kiosk Status"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    print_msg "$BLUE" "Fetching kiosk status..."
    ansible kiosks -i inventory.yml -a "systemctl status kiosk.service --no-pager" -b
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# View logs
view_logs() {
    print_header "View Kiosk Logs"
    
    if [ ! -f inventory.yml ]; then
        print_error "inventory.yml not found"
        read -p "Press Enter to continue..."
        show_menu
        return
    fi
    
    read -p "Number of log lines to show (default: 50): " lines
    lines=${lines:-50}
    
    echo ""
    print_msg "$BLUE" "Fetching last $lines log lines..."
    ansible kiosks -i inventory.yml -a "journalctl -u kiosk.service -n $lines --no-pager" -b
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Main entry point
main() {
    clear
    print_msg "$GREEN" "ISMF Race Logger - Kiosk Setup Quick Start"
    print_msg "$GREEN" "==========================================="
    echo ""
    
    # Check if we're in the right directory
    if [ ! -f "setup-kiosk.yml" ]; then
        print_error "Error: setup-kiosk.yml not found"
        print_error "Please run this script from the ansible/ directory"
        exit 1
    fi
    
    show_menu
}

# Run main
main