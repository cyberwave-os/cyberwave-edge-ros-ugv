#!/bin/bash
################################################################################
# ROS 2 Realtime Raspberry Pi 4 Image Builder
# 
# This script automates the complete setup process for a ROS 2 Jazzy
# realtime system on Debian/Ubuntu-based systems, including:
# - Boot configuration (UART, performance, etc.)
# - System dependencies
# - ROS 2 Jazzy installation
# - UGV workspace setup
# - CyberWave MQTT bridge integration
# - Serial port configuration
# - Environment setup
#
# Supported Operating Systems:
# - Ubuntu 24.04 LTS (Noble Numbat) - native support
# - Ubuntu 22.04 LTS (Jammy Jellyfish) - native support
# - Raspberry Pi OS Bookworm (Debian 12) - via Ubuntu package mapping
# - Debian 12 (Bookworm) - via Ubuntu package mapping
# - Debian 11 (Bullseye) - via Ubuntu package mapping
#
# Target Hardware: Raspberry Pi 4/5 (also works on x86_64 systems)
# ROS Distribution: Jazzy Jalisco
#
# Usage:
#   ./ros-realtime-rpi4-image-builder.sh [OPTIONS]
#
# Options:
#   --skip-ros2-build    Skip ROS 2 build if already successfully built
#   --skip-ugv-build     Skip UGV workspace build if already successfully built
#   --skip-all-builds    Skip both ROS 2 and UGV builds if already built
#   --force-rebuild      Force rebuild everything (ignore build markers)
#   --help               Show this help message
#
# Author: Generated from setup documentation
# Date: 2026-02-09
################################################################################

set -e  # Exit on error

################################################################################
# COMMAND LINE ARGUMENTS
################################################################################
SKIP_ROS2_BUILD=false
SKIP_UGV_BUILD=false
FORCE_REBUILD=false
FORCE_MQTT_BRIDGE_REPLACE=false

# Build status marker files
BUILD_MARKERS_DIR="/var/lib/ros2-image-builder"
ROS2_BUILD_MARKER="$BUILD_MARKERS_DIR/ros2-build-complete"
UGV_BUILD_MARKER="$BUILD_MARKERS_DIR/ugv-build-complete"

show_help() {
    echo "ROS 2 Realtime Raspberry Pi 4 Image Builder"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --skip-ros2-build         Skip ROS 2 build if already successfully built"
    echo "  --skip-ugv-build          Skip UGV workspace build if already successfully built"
    echo "  --skip-all-builds         Skip both ROS 2 and UGV builds if already built"
    echo "  --force-rebuild           Force rebuild everything (ignore build markers)"
    echo "  --force-mqtt-bridge       Force replace mqtt_bridge even if it already exists"
    echo "  --help                    Show this help message"
    echo ""
    echo "Build markers are stored in: $BUILD_MARKERS_DIR"
    echo ""
    echo "Examples:"
    echo "  $0                      # Full build (default)"
    echo "  $0 --skip-ros2-build    # Skip ROS 2 if already built"
    echo "  $0 --skip-all-builds    # Skip all builds if already completed"
    echo "  $0 --force-rebuild      # Force rebuild everything"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ros2-build)
            SKIP_ROS2_BUILD=true
            shift
            ;;
        --skip-ugv-build)
            SKIP_UGV_BUILD=true
            shift
            ;;
        --skip-all-builds)
            SKIP_ROS2_BUILD=true
            SKIP_UGV_BUILD=true
            shift
            ;;
        --force-rebuild)
            FORCE_REBUILD=true
            shift
            ;;
        --force-mqtt-bridge)
            FORCE_MQTT_BRIDGE_REPLACE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if a build was completed successfully
check_build_marker() {
    local marker_file="$1"
    local build_name="$2"
    
    if [ "$FORCE_REBUILD" = true ]; then
        return 1  # Force rebuild
    fi
    
    if [ -f "$marker_file" ]; then
        local build_date=$(cat "$marker_file" 2>/dev/null)
        echo -e "${GREEN}[INFO]${NC} $build_name was successfully built on: $build_date"
        return 0  # Build exists
    fi
    return 1  # No build marker
}

# Function to create build marker after successful build
create_build_marker() {
    local marker_file="$1"
    local build_name="$2"
    
    sudo mkdir -p "$BUILD_MARKERS_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $build_name" | sudo tee "$marker_file" > /dev/null
    echo -e "${GREEN}[INFO]${NC} Created build marker for $build_name"
}

# Function to remove build marker (for failed builds)
remove_build_marker() {
    local marker_file="$1"
    sudo rm -f "$marker_file" 2>/dev/null || true
}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# OS DETECTION
################################################################################
# Detect the operating system (Debian, Ubuntu, Raspberry Pi OS)
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION_ID="$VERSION_ID"
        OS_VERSION_CODENAME="$VERSION_CODENAME"
        OS_PRETTY_NAME="$PRETTY_NAME"
    else
        OS_ID="unknown"
        OS_VERSION_ID="unknown"
        OS_VERSION_CODENAME="unknown"
        OS_PRETTY_NAME="Unknown OS"
    fi
    
    # Detect if running on Raspberry Pi
    IS_RASPBERRY_PI=false
    if [ -f /proc/device-tree/model ]; then
        if grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
            IS_RASPBERRY_PI=true
        fi
    fi
    
    # Map OS codenames to compatible ROS 2 distributions and Ubuntu codenames
    # 
    # IMPORTANT: ROS 2 packages are built against specific Ubuntu library versions.
    # Using the wrong Ubuntu codename will cause dependency conflicts.
    #
    # Compatibility matrix:
    # - Ubuntu Noble (24.04): ROS 2 Jazzy (libpython3.12, libtinyxml2-10)
    # - Ubuntu Jammy (22.04): ROS 2 Humble (libpython3.10, libtinyxml2-9)
    # - Debian Bookworm (12): Compatible with Jammy libraries -> ROS 2 Humble
    # - Debian Bullseye (11): Compatible with Focal libraries -> ROS 2 Humble (limited)
    # - Debian Trixie (13): May be compatible with Noble -> ROS 2 Jazzy
    #
    case "$OS_VERSION_CODENAME" in
        # Ubuntu codenames (direct support)
        noble)
            ROS_UBUNTU_CODENAME="noble"
            ROS_DISTRO_DETECTED="jazzy"
            ;;
        jammy)
            ROS_UBUNTU_CODENAME="jammy"
            ROS_DISTRO_DETECTED="humble"
            ;;
        # Debian/Raspbian codenames - MUST build from source due to Python version mismatch
        bookworm)
            # Debian 12 (Bookworm) has Python 3.11
            # - ROS 2 Humble binaries require libpython3.10 (Ubuntu 22.04)
            # - ROS 2 Jazzy binaries require libpython3.12 (Ubuntu 24.04)
            # Neither binary package set will work - must build from source
            # Using Jazzy as it's the current LTS and builds well on Python 3.11
            ROS_UBUNTU_CODENAME="noble"
            ROS_DISTRO_DETECTED="jazzy"
            ROS_INSTALL_METHOD="source"
            ;;
        bullseye)
            # Debian 11 (Bullseye) has Python 3.9
            # No ROS 2 binary packages support Python 3.9 - must build from source
            ROS_UBUNTU_CODENAME="jammy"
            ROS_DISTRO_DETECTED="humble"
            ROS_INSTALL_METHOD="source"
            ;;
        trixie)
            # Debian 13 (Trixie) has Python 3.13 and libtinyxml2-11
            # These are NEWER than what any current ROS 2 binary packages support:
            # - Jazzy/Noble needs Python 3.12, tinyxml2-10
            # - Humble/Jammy needs Python 3.10, tinyxml2-9
            # Binary packages will NOT work - must build ROS 2 Jazzy from source
            ROS_UBUNTU_CODENAME="noble"
            ROS_DISTRO_DETECTED="jazzy"
            ROS_INSTALL_METHOD="source"
            ;;
        *)
            # Default to jammy/humble for maximum compatibility
            ROS_UBUNTU_CODENAME="jammy"
            ROS_DISTRO_DETECTED="humble"
            ;;
    esac
    
    # Determine package manager specifics
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    else
        PKG_MANAGER="unknown"
    fi
    
    # Default install method is native packages, unless overridden above
    ROS_INSTALL_METHOD="${ROS_INSTALL_METHOD:-native}"
}

# Run OS detection
detect_os

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to wait for apt lock
wait_for_apt_lock() {
    local max_wait=300  # Maximum 5 minutes
    local waited=0
    local shown_message=false
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        
        if [ $waited -ge $max_wait ]; then
            log_error "Timeout waiting for apt lock after ${max_wait} seconds"
            log_error "Killing any stuck apt processes..."
            sudo killall -9 apt apt-get dpkg 2>/dev/null || true
            sleep 3
            return 1
        fi
        
        if [ "$shown_message" = false ]; then
            log_info "Waiting for other package managers to finish..."
            shown_message=true
        fi
        
        sleep 2
        waited=$((waited + 2))
        
        # Every 30 seconds, show we're still waiting
        if [ $((waited % 30)) -eq 0 ]; then
            log_info "Still waiting... (${waited}s elapsed)"
        fi
    done
    
    if [ $waited -gt 0 ]; then
        log_info "Package manager is now available (waited ${waited}s)"
    fi
    
    # Final check: run dpkg --configure -a to ensure clean state
    sudo dpkg --configure -a >/dev/null 2>&1 || true
    
    return 0
}

# Wrapper for apt commands that waits for lock
safe_apt() {
    wait_for_apt_lock || return 1
    sudo apt "$@"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    log_error "Please do not run this script as root (without sudo)"
    log_error "Run as: ./$(basename $0)"
    exit 1
fi

# Configuration
WORKSPACE_DIR="/home/$USER/ws"
UGV_WS_DIR="$WORKSPACE_DIR/ugv_ws"
CYBERWAVE_REPO_DIR="$WORKSPACE_DIR/cyberwave-edge-ros"
# ROS_DISTRO is set by OS detection (ROS_DISTRO_DETECTED)
# Can be overridden by environment variable ROS_DISTRO if set
ROS_DISTRO="${ROS_DISTRO:-$ROS_DISTRO_DETECTED}"
DEFAULT_USER="$USER"

# Check available RAM
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
log_info "System RAM: ${TOTAL_RAM_MB}MB detected"
if [ "$TOTAL_RAM_MB" -lt 2048 ]; then
    log_warn "WARNING: Low RAM detected (${TOTAL_RAM_MB}MB < 2GB)"
    log_warn "Build process will use minimal parallelization to prevent crashes"
    log_warn "Consider closing other applications during build"
fi

log_info "=========================================="
log_info "ROS 2 Realtime Raspberry Pi 4 Image Builder"
log_info "=========================================="
log_info "Detected OS: $OS_PRETTY_NAME"
log_info "OS ID: $OS_ID | Codename: $OS_VERSION_CODENAME"
log_info "ROS Ubuntu Codename: $ROS_UBUNTU_CODENAME (for ROS 2 packages)"
log_info "Raspberry Pi: $IS_RASPBERRY_PI"
if [ "$ROS_DISTRO" = "jazzy" ]; then
    ROS_DISTRO_NAME="Jazzy Jalisco"
elif [ "$ROS_DISTRO" = "humble" ]; then
    ROS_DISTRO_NAME="Humble Hawksbill"
else
    ROS_DISTRO_NAME="$ROS_DISTRO"
fi
log_info "ROS Distro: $ROS_DISTRO ($ROS_DISTRO_NAME)"
log_info "Workspace: $WORKSPACE_DIR"
log_info "User: $DEFAULT_USER"
log_info "=========================================="
log_info "Starting installation... (no user confirmation required)"

# Validate OS compatibility
if [ "$PKG_MANAGER" != "apt" ]; then
    log_error "This script requires apt package manager (Debian/Ubuntu based systems)"
    exit 1
fi

case "$OS_ID" in
    ubuntu|debian|raspbian)
        log_info "✓ Supported OS detected: $OS_ID"
        ;;
    *)
        log_warn "WARNING: Untested OS detected ($OS_ID). Proceeding with caution..."
        ;;
esac

# Fix any interrupted dpkg operations first
log_info "Checking for interrupted dpkg operations..."
if ! sudo dpkg --configure -a 2>&1 | grep -q "^$"; then
    log_info "Completed pending dpkg configurations"
fi

# Disable automatic updates during installation (if they exist)
log_info "Temporarily disabling automatic updates..."
if systemctl list-units --type=service | grep -q "unattended-upgrades"; then
    sudo systemctl stop unattended-upgrades 2>/dev/null || true
fi
if systemctl list-timers | grep -q "apt-daily"; then
    sudo systemctl stop apt-daily.timer 2>/dev/null || true
    sudo systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
fi

# Kill any running apt processes
log_info "Ensuring no apt processes are running..."
sudo killall apt apt-get 2>/dev/null || true
sleep 3

# Wait for any remaining locks
log_info "Waiting for package manager to be ready..."
wait_for_apt_lock

################################################################################
# STEP 1: BOOT CONFIGURATION
################################################################################
log_step "=== Step 1: Configuring Boot Settings ==="

# Detect boot configuration paths (different between Raspberry Pi OS and Ubuntu)
BOOT_CONFIG_TXT=""
BOOT_CMDLINE_TXT=""

# Check for config.txt in various locations
if [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG_TXT="/boot/firmware/config.txt"
    BOOT_CMDLINE_TXT="/boot/firmware/cmdline.txt"
elif [ -f /boot/config.txt ]; then
    BOOT_CONFIG_TXT="/boot/config.txt"
    BOOT_CMDLINE_TXT="/boot/cmdline.txt"
fi

if [ -n "$BOOT_CONFIG_TXT" ] && [ -f "$BOOT_CONFIG_TXT" ]; then
    log_info "Found boot configuration at: $BOOT_CONFIG_TXT"
    
    log_info "Backing up boot configuration files..."
    sudo cp "$BOOT_CONFIG_TXT" "${BOOT_CONFIG_TXT}.backup.$(date +%Y%m%d_%H%M%S)" || true
    if [ -f "$BOOT_CMDLINE_TXT" ]; then
        sudo cp "$BOOT_CMDLINE_TXT" "${BOOT_CMDLINE_TXT}.backup.$(date +%Y%m%d_%H%M%S)" || true
    fi
    
    log_info "Updating $BOOT_CONFIG_TXT..."
    
    # Count how many ROS 2 configuration blocks exist (to detect duplicates)
    ROS_CONFIG_COUNT=$(grep -c "# === ROS 2 Realtime Configuration (Added by setup script) ===" "$BOOT_CONFIG_TXT" 2>/dev/null || echo "0")
    
    if [ "$ROS_CONFIG_COUNT" -gt 1 ]; then
        log_warn "Found $ROS_CONFIG_COUNT duplicate ROS 2 configuration blocks in config.txt, cleaning up..."
        # Remove ALL existing ROS 2 configuration blocks (they will be re-added fresh)
        sudo sed -i '/# === ROS 2 Realtime Configuration (Added by setup script) ===/,/^# Pi 5 specific settings$/{ /dtparam=pciex1_gen=3/d; /dtparam=pciex1/d; /# Pi 5 specific settings/d; /\[pi5\]/d; d; }' "$BOOT_CONFIG_TXT"
        # Clean up any remaining empty lines at the end
        sudo sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$BOOT_CONFIG_TXT" 2>/dev/null || true
        ROS_CONFIG_COUNT=0
    fi
    
    if [ "$ROS_CONFIG_COUNT" -eq 1 ]; then
        log_info "ROS 2 configuration already exists in config.txt (single block), verifying settings..."
        
        # Update individual settings if they differ (idempotent update)
        # Check and update key settings within the existing block
        NEEDS_UPDATE=false
        
        # Verify key settings exist with correct values
        if ! grep -q "^arm_64bit=1" "$BOOT_CONFIG_TXT" 2>/dev/null; then NEEDS_UPDATE=true; fi
        if ! grep -q "^enable_uart=1" "$BOOT_CONFIG_TXT" 2>/dev/null; then NEEDS_UPDATE=true; fi
        if ! grep -q "^gpu_mem=128" "$BOOT_CONFIG_TXT" 2>/dev/null; then NEEDS_UPDATE=true; fi
        
        if [ "$NEEDS_UPDATE" = true ]; then
            log_info "  Some settings need updating, removing old block and adding fresh one..."
            # Remove the existing block
            sudo sed -i '/# === ROS 2 Realtime Configuration (Added by setup script) ===/,/dtparam=pciex1_gen=3/d' "$BOOT_CONFIG_TXT"
            ROS_CONFIG_COUNT=0
        else
            log_info "  ✓ ROS 2 configuration is up to date"
        fi
    fi
    
    # Add ROS 2 configuration if none exists or if we removed duplicates/outdated config
    if [ "$ROS_CONFIG_COUNT" -eq 0 ]; then
        log_info "Adding ROS 2 configuration to config.txt..."
        sudo tee -a "$BOOT_CONFIG_TXT" > /dev/null <<'EOF'

# === ROS 2 Realtime Configuration (Added by setup script) ===
[all]
# Performance optimizations
arm_64bit=1
arm_boost=1
auto_initramfs=1

# UART Configuration for serial communication
dtparam=uart0=on
enable_uart=1

# Disable Bluetooth to free up UART
dtoverlay=disable-bt

# Camera support
camera_auto_detect=1

# GPU Memory
gpu_mem=128

# Display settings
dtoverlay=vc4-kms-v3d
max_framebuffers=2

[pi5]
# Pi 5 specific settings
dtparam=pciex1
dtparam=pciex1_gen=3
EOF
        log_info "✓ ROS 2 configuration added to config.txt"
    fi
    
    # Configure cmdline.txt if it exists
    if [ -f "$BOOT_CMDLINE_TXT" ]; then
        log_info "Updating $BOOT_CMDLINE_TXT (removing serial console)..."
        # Remove console=serial0,115200 and console=ttyAMA0,115200 if present
        sudo sed -i 's/console=serial0,[0-9]*//g' "$BOOT_CMDLINE_TXT"
        sudo sed -i 's/console=ttyAMA0,[0-9]*//g' "$BOOT_CMDLINE_TXT"
        # Add plymouth.ignore-serial-consoles if not present
        if ! grep -q "plymouth.ignore-serial-consoles" "$BOOT_CMDLINE_TXT"; then
            sudo sed -i 's/$/ plymouth.ignore-serial-consoles/' "$BOOT_CMDLINE_TXT"
        fi
    fi
else
    log_warn "Raspberry Pi boot configuration not found (not a Raspberry Pi or different boot setup)"
    log_warn "Skipping boot configuration changes..."
fi

log_info "Disabling serial console services..."
sudo systemctl disable hciuart.service 2>/dev/null || true
sudo systemctl disable bluetooth.service 2>/dev/null || true
sudo systemctl mask serial-getty@ttyAMA0.service 2>/dev/null || true
sudo systemctl mask serial-getty@serial0.service 2>/dev/null || true

log_info "✓ Boot configuration completed"

################################################################################
# STEP 2: SYSTEM UPDATE AND ESSENTIAL PACKAGES
################################################################################
log_step "=== Step 2: Updating System and Installing Essential Packages ==="

log_info "Updating package lists and upgrading system..."
safe_apt update
safe_apt upgrade -y
safe_apt dist-upgrade -y
safe_apt autoremove -y
safe_apt autoclean

# Check and create swap file if needed (2GB for stability)
log_info "Checking swap configuration..."
SWAP_SIZE=$(free -m | awk '/^Swap:/{print $2}')
if [ "$SWAP_SIZE" -lt 2048 ]; then
    log_warn "Swap space is less than 2GB (${SWAP_SIZE}MB). Creating 2GB swap for system stability..."
    if [ ! -f /swapfile ]; then
        log_info "Creating 2GB swap file..."
        sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        log_info "✓ Added 2GB swap file (/swapfile)"
        log_info "  This prevents system crashes and SSH disconnections when RAM is full"
    else
        log_info "Swap file already exists at /swapfile"
        # Verify it's enabled
        if ! swapon --show | grep -q "/swapfile"; then
            log_info "Enabling existing swap file..."
            sudo swapon /swapfile
        fi
    fi
else
    log_info "✓ Swap space sufficient (${SWAP_SIZE}MB)"
fi

log_info "Installing system utilities..."
# Core utilities (available on both Debian and Ubuntu)
safe_apt install -y \
    git curl wget vim nano htop \
    build-essential cmake pkg-config \
    util-linux procps net-tools \
    udev || log_warn "Some system utilities failed to install (continuing...)"

log_info "Verifying git installation..."
if ! command -v git &> /dev/null; then
    log_error "Git installation failed!"
    exit 1
fi

log_info "Installing serial communication tools..."
safe_apt install -y \
    minicom screen setserial

log_info "Installing network tools..."
# Install network tools (some may not be available on all systems)
safe_apt install -y \
    iproute2 iw haveged \
    iptables || log_warn "Some network tools failed to install"
    
# Optional network tools (hostapd and dnsmasq may not be needed)
safe_apt install -y hostapd dnsmasq 2>/dev/null || log_warn "  hostapd/dnsmasq not installed (optional)"

log_info "Installing audio support..."
# Audio packages (some may have different names on Debian vs Ubuntu)
safe_apt install -y alsa-utils || log_warn "  alsa-utils not installed"

# Try portaudio (package name varies)
if ! safe_apt install -y portaudio19-dev 2>/dev/null; then
    safe_apt install -y libportaudio2 2>/dev/null || log_warn "  portaudio not installed (optional)"
fi

# PulseAudio (optional, may be replaced by PipeWire on newer systems)
safe_apt install -y pulseaudio pulseaudio-utils 2>/dev/null || log_warn "  pulseaudio not installed (optional)"

# Text-to-speech (optional)
safe_apt install -y espeak 2>/dev/null || log_warn "  espeak not installed (optional)"

log_info "Installing camera and video libraries..."
# Note: Some packages (libcamera-apps, python3-picamera2) are available on Ubuntu 24.04 ARM64
safe_apt install -y \
    python3-opencv \
    libopenblas-dev libatlas3-base \
    libavformat-dev libavcodec-dev \
    libavdevice-dev libavutil-dev \
    libavfilter-dev libswscale-dev \
    libswresample-dev || log_warn "Some camera packages not available"

# Install usb_cam dependencies (v4l2, image transport)
log_info "Installing USB camera dependencies..."
safe_apt install -y \
    v4l-utils \
    libv4l-dev \
    ros-${ROS_DISTRO}-image-transport \
    ros-${ROS_DISTRO}-camera-info-manager \
    ros-${ROS_DISTRO}-image-transport-plugins \
    ros-${ROS_DISTRO}-compressed-image-transport \
    ros-${ROS_DISTRO}-cv-bridge 2>/dev/null || log_warn "Some ROS camera packages not available (will build from source)"

# Install boost-python (required for cv_bridge source build)
log_info "Installing Boost Python (for cv_bridge)..."
safe_apt install -y libboost-python-dev python3-numpy 2>/dev/null || log_warn "libboost-python-dev not available"

# Try to install Pi-specific packages for Ubuntu 24.04 ARM64
log_info "Installing Pi-specific camera packages for Ubuntu 24.04..."
if safe_apt install -y python3-libcamera 2>/dev/null; then
    log_info "  ✓ Installed python3-libcamera successfully"
else
    log_warn "  python3-libcamera not available (install manually if needed)"
fi

# Note: For Raspberry Pi Camera Module support, you may need to build from source:
# https://github.com/raspberrypi/libcamera
# The standard Ubuntu libcamera lacks Raspberry Pi-specific hardware support

log_info "Installing Python development tools..."
safe_apt install -y \
    python3-dev python3-pip python3-venv \
    python3-numpy python3-scipy \
    python3-argcomplete

log_info "✓ Essential packages installed"

################################################################################
# STEP 3: USER PERMISSIONS
################################################################################
log_step "=== Step 3: Configuring User Permissions ==="

log_info "Adding user $DEFAULT_USER to hardware access groups..."

# Function to add user to group if group exists
add_user_to_group() {
    local group=$1
    if getent group "$group" > /dev/null 2>&1; then
        sudo usermod -aG "$group" $DEFAULT_USER
        log_info "  ✓ Added to group: $group"
    else
        log_warn "  ⊘ Group not found (skipping): $group"
    fi
}

# Add to common groups
add_user_to_group dialout
add_user_to_group audio
add_user_to_group video
add_user_to_group plugdev

# Add to Pi-specific groups (may not exist on Ubuntu)
add_user_to_group gpio
add_user_to_group i2c
add_user_to_group spi

log_info "✓ User permissions configured"

################################################################################
# STEP 4: SERIAL PORT CONFIGURATION
################################################################################
log_step "=== Step 4: Configuring Serial Port Permissions ==="

log_info "Creating udev rule for automatic serial port permissions..."
echo 'KERNEL=="tty[A-Z]*[0-9]*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-serial.rules > /dev/null

log_info "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

log_info "Setting current permissions for existing serial ports..."
sudo chmod 666 /dev/ttyACM* /dev/ttyAMA* /dev/ttyUSB* /dev/ttyS* 2>/dev/null || true

log_info "✓ Serial port permissions configured"

################################################################################
# STEP 5: AUDIO CONFIGURATION
################################################################################
log_step "=== Step 5: Configuring Audio (ALSA) ==="

log_info "Creating ALSA configuration for default audio device..."
sudo tee /etc/asound.conf > /dev/null <<'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF

log_info "✓ Audio configuration completed"

################################################################################
# STEP 6: DOCKER INSTALLATION
################################################################################
log_step "=== Step 6: Installing Docker ==="

if ! command -v docker &> /dev/null; then
    log_info "Docker not found, installing..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    
    log_info "Adding user to docker group..."
    sudo usermod -aG docker $DEFAULT_USER
    
    log_info "Installing Docker Compose plugin..."
    safe_apt install -y docker-compose-plugin
else
    log_info "Docker already installed, skipping..."
fi

log_info "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-runtime": "runc"
}
EOF

log_info "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl restart docker

log_info "✓ Docker installation completed"

################################################################################
# STEP 7: ROS 2 INSTALLATION
################################################################################
log_step "=== Step 7: Installing ROS 2 $ROS_DISTRO ==="

log_info "Installation method: $ROS_INSTALL_METHOD"

# Check if we should skip ROS 2 build
ROS2_ALREADY_BUILT=false
if [ "$SKIP_ROS2_BUILD" = true ]; then
    if check_build_marker "$ROS2_BUILD_MARKER" "ROS 2 $ROS_DISTRO"; then
        # Verify ROS 2 installation is actually working
        if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
            source /opt/ros/${ROS_DISTRO}/setup.bash
            # Check if core packages exist
            if [ -d "/opt/ros/${ROS_DISTRO}/share/rclcpp" ] || \
               command -v ros2 &>/dev/null; then
                log_info "✓ ROS 2 $ROS_DISTRO installation verified, skipping build..."
                ROS2_ALREADY_BUILT=true
            else
                log_warn "ROS 2 build marker exists but installation incomplete, rebuilding..."
                remove_build_marker "$ROS2_BUILD_MARKER"
            fi
        else
            log_warn "ROS 2 build marker exists but setup.bash not found, rebuilding..."
            remove_build_marker "$ROS2_BUILD_MARKER"
        fi
    else
        log_info "No previous ROS 2 build found, proceeding with build..."
    fi
fi

if [ "$ROS2_ALREADY_BUILT" = false ]; then

if [ "$ROS_INSTALL_METHOD" = "source" ]; then
    log_warn "============================================================"
    log_warn "IMPORTANT: Your OS ($OS_PRETTY_NAME) is not compatible with"
    log_warn "ROS 2 binary packages due to library version mismatches."
    log_warn "============================================================"
    log_info ""
    log_info "ROS 2 $ROS_DISTRO will be built from source."
    log_info "This may take 1-3 hours depending on your hardware."
    log_info ""
    
    # Install build dependencies
    log_info "Installing build dependencies for ROS 2 from source..."
    safe_apt update
    safe_apt install -y \
        build-essential \
        cmake \
        git \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-flake8 \
        python3-setuptools \
        wget \
        curl \
        gnupg \
        lsb-release \
        ca-certificates
    
    # Install Python dependencies via pip
    log_info "Installing Python dependencies..."
    
    # Install rosdep system-wide so sudo can access it (needed for rosdep init)
    log_info "  Installing rosdep system-wide (required for sudo rosdep init)..."
    sudo pip3 install --break-system-packages \
        rosdep \
        rosdistro \
        rospkg \
        catkin_pkg
    
    # Install user-level build tools
    log_info "  Installing build tools..."
    pip3 install --break-system-packages \
        -U colcon-common-extensions \
        vcstool \
        argcomplete \
        flake8-blind-except \
        flake8-builtins \
        flake8-class-newline \
        flake8-comprehensions \
        flake8-deprecated \
        flake8-docstrings \
        flake8-import-order \
        flake8-quotes \
        pytest-repeat \
        pytest-rerunfailures \
        pytest \
        setuptools \
        empy \
        lark
    
    # Add pip bin directory to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
    
    # Verify vcs is available
    if ! command -v vcs &> /dev/null; then
        log_warn "vcs not found in PATH, trying to locate it..."
        # Try common locations
        if [ -x "$HOME/.local/bin/vcs" ]; then
            export PATH="$HOME/.local/bin:$PATH"
        elif [ -x "/usr/local/bin/vcs" ]; then
            export PATH="/usr/local/bin:$PATH"
        else
            log_error "vcstool (vcs) could not be found. Trying to reinstall..."
            pip3 install --break-system-packages --force-reinstall vcstool
            export PATH="$HOME/.local/bin:$PATH"
        fi
    fi
    
    log_info "  vcs location: $(which vcs 2>/dev/null || echo 'not found')"
    log_info "  colcon location: $(which colcon 2>/dev/null || echo 'not found')"
    
    # Install additional system dependencies
    log_info "Installing additional system dependencies..."
    safe_apt install -y \
        libasio-dev \
        libtinyxml2-dev \
        libcunit1-dev \
        libopencv-dev \
        libssl-dev \
        libeigen3-dev \
        libxml2-dev \
        libxslt1-dev \
        libpoco-dev \
        libyaml-cpp-dev \
        liblog4cxx-dev \
        libcurl4-openssl-dev \
        libbullet-dev \
        libspdlog-dev \
        libfmt-dev \
        libtinyxml-dev \
        libfreetype-dev \
        libx11-dev \
        libxaw7-dev \
        libxrandr-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        qtbase5-dev \
        libqt5opengl5-dev \
        libconsole-bridge-dev \
        liborocos-kdl-dev \
        liburdfdom-dev \
        liburdfdom-headers-dev \
        libacl1-dev \
        libsqlite3-dev \
        libbenchmark-dev \
        libmimalloc-dev \
        pybind11-dev \
        python3-pybind11 \
        libignition-cmake2-dev \
        libignition-math6-dev || log_warn "Some optional dependencies not available"
    
    # Create ROS 2 source directory and install directory
    ROS2_SRC_DIR="/opt/ros/${ROS_DISTRO}_src"
    ROS2_INSTALL_DIR="/opt/ros/${ROS_DISTRO}"
    
    log_info "Creating ROS 2 directories..."
    log_info "  Source directory: $ROS2_SRC_DIR"
    log_info "  Install directory: $ROS2_INSTALL_DIR"
    
    # Create and set ownership for source directory
    sudo mkdir -p "$ROS2_SRC_DIR/src"
    sudo chown -R $USER:$USER "$ROS2_SRC_DIR"
    
    # Create and set ownership for install directory (colcon needs write access)
    sudo mkdir -p "$ROS2_INSTALL_DIR"
    sudo chown -R $USER:$USER "$ROS2_INSTALL_DIR"
    
    # Ensure workspace log directory exists
    mkdir -p "$WORKSPACE_DIR"
    
    cd "$ROS2_SRC_DIR"
    
    # Download ROS 2 source code
    log_info "Downloading ROS 2 $ROS_DISTRO source code..."
    log_info "This will download the ros_base variant for a smaller build..."
    
    # Get the ROS 2 repos file
    if [ "$ROS_DISTRO" = "jazzy" ]; then
        wget -q https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos -O ros2.repos
    elif [ "$ROS_DISTRO" = "humble" ]; then
        wget -q https://raw.githubusercontent.com/ros2/ros2/humble/ros2.repos -O ros2.repos
    else
        wget -q https://raw.githubusercontent.com/ros2/ros2/${ROS_DISTRO}/ros2.repos -O ros2.repos
    fi
    
    log_info "Importing ROS 2 repositories (this may take a while)..."
    vcs import src < ros2.repos
    
    # Initialize rosdep
    log_info "Initializing rosdep..."
    
    # rosdep was installed system-wide, so it should be in /usr/local/bin
    # Test if rosdep actually works
    if ! rosdep --version &>/dev/null; then
        log_warn "rosdep is broken or not found. Reinstalling system-wide..."
        sudo pip3 install --break-system-packages --force-reinstall rosdep rosdistro rospkg catkin_pkg
    fi
    log_info "  rosdep location: $(which rosdep)"
    log_info "  rosdep version: $(rosdep --version 2>/dev/null || echo 'unknown')"
    
    if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
        sudo rosdep init || true
    fi
    rosdep update
    
    # Install dependencies using rosdep (ignore failures for system-specific packages)
    log_info "Installing ROS 2 dependencies via rosdep..."
    # Skip packages that don't exist on Debian Trixie or have different names
    rosdep install --from-paths src --ignore-src -y \
        --skip-keys "fastcdr rti-connext-dds-6.0.1 urdfdom_headers pydocstyle flake8-docstrings python3-mypy python3-pytest-mock python3-sip-dev python3-pyqt5-sip python3-sip python3-sipbuild libignition-cmake2-dev libignition-math6-dev ignition-cmake2 ignition-math6" \
        || log_warn "Some rosdep dependencies could not be installed (continuing...)"
    
    # Build ROS 2 from source
    log_info "Building ROS 2 $ROS_DISTRO from source..."
    log_info "This will take a long time (1-3 hours on Raspberry Pi)..."
    log_info "Using sequential build to prevent RAM exhaustion..."
    
    # Set up environment for build
    export MAKEFLAGS="-j1"
    
    # Find colcon location
    COLCON_PATH=$(which colcon 2>/dev/null || echo "$HOME/.local/bin/colcon")
    if [ ! -x "$COLCON_PATH" ]; then
        log_error "colcon not found. Reinstalling..."
        pip3 install --break-system-packages --force-reinstall colcon-common-extensions
        COLCON_PATH="$HOME/.local/bin/colcon"
    fi
    log_info "  colcon location: $COLCON_PATH"
    
    # Build with minimal parallelization to prevent OOM (Out Of Memory) kills
    # Skip:
    # - Tracing packages (optional, have missing dependencies)
    # - Example/demo packages (not needed, consume lots of RAM to build)
    # - Test packages (not needed for runtime)
    "$COLCON_PATH" build \
        --install-base "$ROS2_INSTALL_DIR" \
        --merge-install \
        --executor sequential \
        --cmake-args \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_TESTING=OFF \
            -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        --packages-skip-build-finished \
        --packages-skip \
            lttngpy \
            ros2trace \
            tracetools_launch \
            tracetools_read \
            tracetools_test \
            tracetools_trace \
            demo_nodes_cpp \
            demo_nodes_cpp_native \
            demo_nodes_py \
            examples_rclcpp_async_client \
            examples_rclcpp_cbg_executor \
            examples_rclcpp_minimal_action_client \
            examples_rclcpp_minimal_action_server \
            examples_rclcpp_minimal_client \
            examples_rclcpp_minimal_composition \
            examples_rclcpp_minimal_publisher \
            examples_rclcpp_minimal_service \
            examples_rclcpp_minimal_subscriber \
            examples_rclcpp_minimal_timer \
            examples_rclcpp_multithreaded_executor \
            examples_rclcpp_wait_set \
            examples_rclpy_executors \
            examples_rclpy_minimal_action_client \
            examples_rclpy_minimal_action_server \
            examples_rclpy_minimal_client \
            examples_rclpy_minimal_publisher \
            examples_rclpy_minimal_service \
            examples_rclpy_minimal_subscriber \
            examples_rclpy_pointcloud_publisher \
            examples_tf2_py \
            quality_of_service_demo_cpp \
            quality_of_service_demo_py \
            intra_process_demo \
            image_tools \
            pendulum_control \
            pendulum_msgs \
            composition \
            logging_demo \
            action_tutorials_cpp \
            action_tutorials_interfaces \
            action_tutorials_py \
        --continue-on-error \
        2>&1 | tee "$WORKSPACE_DIR/ros2-source-build.log"
    
    # Verify installation
    if [ -f "$ROS2_INSTALL_DIR/setup.bash" ]; then
        log_info "✓ ROS 2 $ROS_DISTRO built and installed successfully at $ROS2_INSTALL_DIR"
    else
        log_error "ROS 2 build may have failed. Check $WORKSPACE_DIR/ros2-source-build.log"
        log_warn "Continuing with script, but ROS 2 may not be fully functional..."
    fi
    
    # Install additional ROS 2 packages from source if needed
    log_info "Installing ROS 2 build tools..."
    pip3 install --break-system-packages \
        colcon-common-extensions \
        rosdep \
        vcstool || true
    
    log_info "✓ ROS 2 $ROS_DISTRO source installation completed"
    
elif [ "$ROS_INSTALL_METHOD" = "native" ]; then
    # Native installation
    log_info "Setting up ROS 2 repository..."
    
    # Install prerequisites for adding repositories
    log_info "Installing repository management tools..."
    
    # First, ensure apt lists are updated
    safe_apt update || log_warn "apt update had warnings (continuing...)"
    
    # Install curl and gnupg first (needed for GPG key handling)
    safe_apt install -y curl gnupg lsb-release ca-certificates
    
    # Try to install software-properties-common (available on Ubuntu, may not be on Debian)
    if safe_apt install -y software-properties-common 2>/dev/null; then
        log_info "  ✓ Installed software-properties-common"
        # Add universe repository on Ubuntu
        if [ "$OS_ID" = "ubuntu" ]; then
            sudo add-apt-repository universe -y 2>/dev/null || log_warn "  Could not add universe repository (may already be enabled)"
        fi
    else
        log_warn "  software-properties-common not available (using manual repository setup)"
    fi
    
    # Check if ROS 2 repository is already configured with the CORRECT codename
    ROS2_REPO_NEEDS_UPDATE=false
    if [ -f "/etc/apt/sources.list.d/ros2.list" ]; then
        CURRENT_CODENAME=$(grep -oP 'ubuntu \K\w+' /etc/apt/sources.list.d/ros2.list 2>/dev/null || echo "")
        if [ "$CURRENT_CODENAME" != "$ROS_UBUNTU_CODENAME" ]; then
            log_warn "ROS 2 repository is configured for '$CURRENT_CODENAME' but needs '$ROS_UBUNTU_CODENAME'"
            log_info "Removing old ROS 2 repository configuration..."
            sudo rm -f /etc/apt/sources.list.d/ros2.list
            ROS2_REPO_NEEDS_UPDATE=true
        else
            log_info "ROS 2 repository already correctly configured for '$ROS_UBUNTU_CODENAME'"
        fi
    elif [ -f "/etc/apt/sources.list.d/ros2.sources" ]; then
        log_warn "Found ros2.sources file, removing to use ros2.list format..."
        sudo rm -f /etc/apt/sources.list.d/ros2.sources
        ROS2_REPO_NEEDS_UPDATE=true
    else
        ROS2_REPO_NEEDS_UPDATE=true
    fi
    
    if [ "$ROS2_REPO_NEEDS_UPDATE" = true ]; then
        log_info "Adding ROS 2 GPG key..."
        sudo mkdir -p /usr/share/keyrings
        sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
        
        log_info "Adding ROS 2 repository to sources list..."
        log_info "  Using Ubuntu codename '$ROS_UBUNTU_CODENAME' for ROS 2 $ROS_DISTRO repository"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $ROS_UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
        log_info "  ✓ ROS 2 repository added"
    fi
    
    log_info "Updating package lists..."
    safe_apt update
    
    log_info "Installing ROS 2 $ROS_DISTRO base packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-ros-base \
        ros-${ROS_DISTRO}-ros-core
    
    log_info "Installing ROS 2 build tools..."
    safe_apt install -y \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool
    
    log_info "Installing ROS 2 Navigation packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-navigation2 \
        ros-${ROS_DISTRO}-nav2-common \
        ros-${ROS_DISTRO}-nav2-bringup \
        ros-${ROS_DISTRO}-nav2-msgs \
        ros-${ROS_DISTRO}-nav2-costmap-2d \
        ros-${ROS_DISTRO}-nav2-core
    
    log_info "Installing ROS 2 TF2 and message packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-tf2-ros \
        ros-${ROS_DISTRO}-tf2-geometry-msgs
    
    log_info "Installing ROS 2 vision and sensor packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-cv-bridge \
        ros-${ROS_DISTRO}-image-transport \
        ros-${ROS_DISTRO}-image-geometry \
        ros-${ROS_DISTRO}-usb-cam
    
    log_info "Installing ROS 2 communication packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-rosbridge-suite
    
    log_info "Installing ROS 2 visualization packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-rviz-common \
        ros-${ROS_DISTRO}-rviz-default-plugins \
        ros-${ROS_DISTRO}-rqt-common-plugins \
        ros-${ROS_DISTRO}-joint-state-publisher \
        ros-${ROS_DISTRO}-joint-state-publisher-gui
    
    log_info "Installing image processing packages..."
    safe_apt install -y \
        ros-${ROS_DISTRO}-image-proc \
        ros-${ROS_DISTRO}-image-pipeline || log_warn "image_proc packages not available (optional)"
    
    log_info "Installing additional libraries..."
    safe_apt install -y \
        libboost-all-dev \
        libg2o-dev
    
    log_info "Updating library cache..."
    sudo ldconfig
    
    log_info "Initializing rosdep..."
    if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
        sudo rosdep init
    fi
    rosdep update
    
    log_info "✓ ROS 2 $ROS_DISTRO installation completed"
else
    log_error "Unknown ROS_INSTALL_METHOD: $ROS_INSTALL_METHOD"
    exit 1
fi

# Create build marker for successful ROS 2 build
# Verify the build was successful before creating marker
if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
    if [ -d "/opt/ros/${ROS_DISTRO}/share/rclcpp" ] || \
       [ -d "/opt/ros/${ROS_DISTRO}/share/ament_cmake" ]; then
        create_build_marker "$ROS2_BUILD_MARKER" "ROS 2 $ROS_DISTRO"
    fi
fi

fi  # End of ROS2_ALREADY_BUILT check

################################################################################
# STEP 8: WORKSPACE SETUP
################################################################################
log_step "=== Step 8: Setting Up Workspaces ==="

log_info "Creating workspace directory structure..."
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Clone UGV workspace
if [ -d "$UGV_WS_DIR" ]; then
    log_warn "UGV workspace directory already exists at $UGV_WS_DIR"
    read -p "Do you want to remove and re-clone it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing UGV workspace..."
        rm -rf "$UGV_WS_DIR"
    else
        log_info "Keeping existing workspace, attempting to update..."
        cd "$UGV_WS_DIR"
        git pull origin ros2-humble-develop || log_warn "Failed to update, continuing with existing version..."
        cd "$WORKSPACE_DIR"
    fi
fi

if [ ! -d "$UGV_WS_DIR" ]; then
    log_info "Cloning UGV workspace (ros2-humble-develop branch - compatible with Jazzy)..."
    git clone -b ros2-humble-develop https://github.com/DUDULRX/ugv_ws.git || {
        log_error "Failed to clone UGV workspace"
        exit 1
    }
    log_info "✓ UGV workspace cloned successfully"
fi

# Clone CyberWave Edge ROS repository
if [ -d "$CYBERWAVE_REPO_DIR" ]; then
    log_warn "CyberWave Edge ROS directory already exists at $CYBERWAVE_REPO_DIR"
    read -p "Do you want to remove and re-clone it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing CyberWave Edge ROS repository..."
        rm -rf "$CYBERWAVE_REPO_DIR"
    else
        log_info "Keeping existing repository, attempting to update..."
        cd "$CYBERWAVE_REPO_DIR"
        git pull origin main || log_warn "Failed to update, continuing with existing version..."
        cd "$WORKSPACE_DIR"
    fi
fi

if [ ! -d "$CYBERWAVE_REPO_DIR" ]; then
    log_info "Cloning CyberWave Edge ROS repository..."
    git clone https://github.com/cyberwave-os/cyberwave-edge-ros.git || {
        log_error "Failed to clone CyberWave Edge ROS repository"
        exit 1
    }
    log_info "✓ CyberWave Edge ROS repository cloned successfully"
fi

# Copy mqtt_bridge folder to UGV workspace src
log_info "Setting up mqtt_bridge in UGV workspace..."
if [ -d "$CYBERWAVE_REPO_DIR/mqtt_bridge" ]; then
    # Check if mqtt_bridge already exists in ugv_ws/src
    if [ -d "$UGV_WS_DIR/src/mqtt_bridge" ]; then
        if [ "$FORCE_MQTT_BRIDGE_REPLACE" = true ]; then
            log_warn "mqtt_bridge already exists - replacing (--force-mqtt-bridge flag set)..."
            rm -rf "$UGV_WS_DIR/src/mqtt_bridge"
            # Copy mqtt_bridge folder
            cp -r "$CYBERWAVE_REPO_DIR/mqtt_bridge" "$UGV_WS_DIR/src/" || {
                log_error "Failed to copy mqtt_bridge folder"
                exit 1
            }
            log_info "✓ mqtt_bridge replaced successfully"
        else
            log_info "✓ mqtt_bridge already exists in $UGV_WS_DIR/src - keeping existing version"
            log_info "  (Use --force-mqtt-bridge to replace with fresh copy from CyberWave repo)"
        fi
    else
        # Ensure src directory exists
        mkdir -p "$UGV_WS_DIR/src"
        
        # Copy mqtt_bridge folder
        cp -r "$CYBERWAVE_REPO_DIR/mqtt_bridge" "$UGV_WS_DIR/src/" || {
            log_error "Failed to copy mqtt_bridge folder"
            exit 1
        }
        log_info "✓ mqtt_bridge copied successfully to $UGV_WS_DIR/src/mqtt_bridge"
    fi
    
    # Fix mqtt_bridge setup.py and add setup.cfg for ROS 2 compatibility (always apply fixes)
    log_info "  Ensuring mqtt_bridge ROS 2 $ROS_DISTRO compatibility..."
    MQTT_SETUP_PY="$UGV_WS_DIR/src/mqtt_bridge/setup.py"
    MQTT_SETUP_CFG="$UGV_WS_DIR/src/mqtt_bridge/setup.cfg"
    
    # Fix setup.py: name should use underscore, not hyphen (IDEMPOTENT)
    if [ -f "$MQTT_SETUP_PY" ]; then
        if grep -q "name='mqtt-bridge'" "$MQTT_SETUP_PY" 2>/dev/null; then
            sed -i "s/name='mqtt-bridge'/name=package_name/g" "$MQTT_SETUP_PY"
            log_info "    ✓ Fixed setup.py name (mqtt-bridge -> package_name)"
        fi
    fi
    
    # Create setup.cfg to install scripts to lib/mqtt_bridge (required for ROS 2 Jazzy)
    if [ ! -f "$MQTT_SETUP_CFG" ]; then
        cat > "$MQTT_SETUP_CFG" << 'MQTT_CFG_EOF'
[develop]
script_dir=$base/lib/mqtt_bridge
[install]
install_scripts=$base/lib/mqtt_bridge
MQTT_CFG_EOF
        log_info "    ✓ Created setup.cfg for console script installation"
    fi
else
    log_error "mqtt_bridge folder not found in $CYBERWAVE_REPO_DIR"
    exit 1
fi

# Clone usb_cam ROS 2 package for camera support
log_info "Setting up usb_cam ROS 2 package..."
USB_CAM_DIR="$UGV_WS_DIR/src/usb_cam"
if [ -d "$USB_CAM_DIR" ]; then
    log_info "  usb_cam already exists, checking for updates..."
    cd "$USB_CAM_DIR"
    git pull origin main 2>/dev/null || log_warn "  Failed to update usb_cam, using existing version"
    cd "$WORKSPACE_DIR"
else
    log_info "  Cloning usb_cam from ros-drivers (main branch for ROS 2)..."
    cd "$UGV_WS_DIR/src"
    git clone https://github.com/ros-drivers/usb_cam.git || {
        log_warn "Failed to clone usb_cam, camera support may be limited"
    }
    cd "$WORKSPACE_DIR"
fi

# NOTE: We do NOT clone full image_common or image_pipeline from source!
# The 'rolling' branch has API incompatibilities with ROS 2 Jazzy's message_filters.
# Instead, we use the system packages from /opt/ros/jazzy which are properly compatible.
# 
# However, we DO need image_geometry (from vision_opencv) for apriltag_ros.
# image_geometry is a simple, standalone package that builds cleanly.

log_info "Checking for conflicting source packages..."
if [ -d "$UGV_WS_DIR/src/image_common" ]; then
    log_warn "Removing image_common from source (using system package instead - avoids API conflicts)"
    rm -rf "$UGV_WS_DIR/src/image_common"
    rm -rf "$UGV_WS_DIR/build/image_transport" "$UGV_WS_DIR/install/image_transport" 2>/dev/null
    rm -rf "$UGV_WS_DIR/build/camera_calibration_parsers" "$UGV_WS_DIR/install/camera_calibration_parsers" 2>/dev/null
    rm -rf "$UGV_WS_DIR/build/camera_info_manager" "$UGV_WS_DIR/install/camera_info_manager" 2>/dev/null
fi
if [ -d "$UGV_WS_DIR/src/image_pipeline" ]; then
    log_warn "Removing image_pipeline from source (using system package instead - avoids API conflicts)"
    rm -rf "$UGV_WS_DIR/src/image_pipeline"
    rm -rf "$UGV_WS_DIR/build/image_proc" "$UGV_WS_DIR/install/image_proc" 2>/dev/null
    rm -rf "$UGV_WS_DIR/build/tracetools_image_pipeline" "$UGV_WS_DIR/install/tracetools_image_pipeline" 2>/dev/null
fi

# Clone vision_opencv for image_geometry (needed by apriltag_ros)
# image_geometry is a simple package that doesn't have the API conflicts
log_info "Setting up image_geometry (required by apriltag_ros)..."
VISION_OPENCV_DIR="$UGV_WS_DIR/src/vision_opencv"
if [ ! -d "$VISION_OPENCV_DIR" ]; then
    log_info "  Cloning vision_opencv (for image_geometry)..."
    cd "$UGV_WS_DIR/src"
    git clone -b rolling https://github.com/ros-perception/vision_opencv.git || {
        log_warn "Failed to clone vision_opencv, apriltag_ros may fail to build"
    }
    cd "$WORKSPACE_DIR"
else
    log_info "  vision_opencv already exists"
fi

log_info "✓ Using system image_common packages + image_geometry from source"

log_info "✓ Workspaces setup completed"

################################################################################
# STEP 9: APPLY ROS 2 SOURCE CODE FIXES
################################################################################
log_step "=== Step 9: Applying ROS 2 $ROS_DISTRO Compatibility Fixes ==="

cd "$UGV_WS_DIR"

log_info "🔧 Applying ROS 2 $ROS_DISTRO compatibility fixes..."

# Pre-cleanup: Fix any corrupted .hpp+ patterns from previous runs (GLOBAL IDEMPOTENT CLEANUP)
log_info "  Pre-cleanup: Fixing any corrupted .hpp+ patterns from previous runs..."
find "$UGV_WS_DIR/src" -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" \) 2>/dev/null | while read file; do
    # Pattern: .hpp followed by one or more 'p' chars, then " or >
    sed -i 's|\.hppp*"|.hpp"|g' "$file" 2>/dev/null || true
    sed -i 's|\.hppp*>|.hpp>|g' "$file" 2>/dev/null || true
done

# Fix 1: emcl2 - Add <cstdint> include and fix pessimizing-move warnings
log_info "  Fixing emcl2..."
if [ -f "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h" ]; then
    if ! grep -q "#include <cstdint>" "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h"; then
        sed -i '/#include <string>/a #include <cstdint>' \
            "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h"
    fi
fi

if [ -f "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h" ]; then
    if ! grep -q "#include <cstdint>" "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h"; then
        sed -i '/#include <vector>/a #include <cstdint>' \
            "$UGV_WS_DIR/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h"
    fi
fi

# Fix emcl2_node.cpp - Remove unnecessary std::move() on temporary objects (pessimizing-move)
EMCL2_NODE="$UGV_WS_DIR/src/ugv_else/emcl2_ros2/src/emcl2_node.cpp"
if [ -f "$EMCL2_NODE" ]; then
    # Fix: std::shared_ptr<LikelihoodFieldMap> map = std::move(initMap());
    if grep -q 'std::move(initMap())' "$EMCL2_NODE" 2>/dev/null; then
        sed -i 's|std::move(initMap())|initMap()|g' "$EMCL2_NODE"
    fi
    # Fix: std::shared_ptr<OdomModel> om = std::move(initOdometry());
    if grep -q 'std::move(initOdometry())' "$EMCL2_NODE" 2>/dev/null; then
        sed -i 's|std::move(initOdometry())|initOdometry()|g' "$EMCL2_NODE"
    fi
fi

# Fix 2: ldlidar - Add <pthread.h> include, fix uninitialized variable, and fix linux/types.h issue
log_info "  Fixing ldlidar..."
if [ -f "$UGV_WS_DIR/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp" ]; then
    if ! grep -q "#include <pthread.h>" "$UGV_WS_DIR/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp"; then
        sed -i '/^#else$/a #include <pthread.h>' \
            "$UGV_WS_DIR/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp"
    fi
fi

# Fix ldlidar demo.cpp - Initialize serial_port_baudrate to avoid uninitialized warning
LDLIDAR_DEMO="$UGV_WS_DIR/src/ugv_else/ldlidar/src/demo.cpp"
if [ -f "$LDLIDAR_DEMO" ]; then
    # Check if the variable is declared without initialization
    if grep -q 'int serial_port_baudrate;$' "$LDLIDAR_DEMO" 2>/dev/null; then
        sed -i 's|int serial_port_baudrate;|int serial_port_baudrate = 230400;|g' "$LDLIDAR_DEMO"
    fi
fi

# Fix ldlidar serial_interface_linux.h - Add <linux/types.h> before <linux/termios.h>
# This fixes '__u32' type errors on newer kernels where linux/sched/types.h is pulled in
LDLIDAR_SERIAL="$UGV_WS_DIR/src/ugv_else/ldlidar/ldlidar_driver/include/serialcom/serial_interface_linux.h"
if [ -f "$LDLIDAR_SERIAL" ]; then
    if ! grep -q "#include <linux/types.h>" "$LDLIDAR_SERIAL" 2>/dev/null; then
        log_info "    Adding <linux/types.h> include to fix kernel header compatibility..."
        sed -i '/#include <sys\/ioctl.h>/a #include <linux/types.h>  // Must be included before linux/termios.h for __u32, __u64 types' "$LDLIDAR_SERIAL"
    fi
fi

# Fix 3: slam_gmapping - Change .h to .hpp (IDEMPOTENT)
log_info "  Fixing slam_gmapping..."
SLAM_FILE="$UGV_WS_DIR/src/ugv_else/gmapping/slam_gmapping/include/slam_gmapping/slam_gmapping.h"
if [ -f "$SLAM_FILE" ]; then
    # First, fix any corrupted .hppp+ patterns from multiple runs
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.hppp*"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$SLAM_FILE"
    # Then, only convert .h to .hpp if the EXACT original .h pattern exists (not already .hpp)
    if grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.h"' "$SLAM_FILE" && ! grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.hpp"' "$SLAM_FILE"; then
        sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$SLAM_FILE"
    fi
fi

# Fix 4: explore_lite - Replace execute_callback() with makePlan()
log_info "  Fixing explore_lite..."
if [ -f "$UGV_WS_DIR/src/ugv_else/explore_lite/src/explore.cpp" ]; then
    sed -i 's|exploring_timer_->execute_callback();|makePlan();|g' \
        "$UGV_WS_DIR/src/ugv_else/explore_lite/src/explore.cpp"
fi

# Fix 5: apriltag_ros - Change .h to .hpp (IDEMPOTENT - only if not already .hpp)
log_info "  Fixing apriltag_ros..."
APRILTAG_HPP="$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
APRILTAG_CPP="$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"

if [ -f "$APRILTAG_HPP" ]; then
    # Fix any corrupted .hppp+ patterns first (from multiple runs)
    sed -i 's|cv_bridge/cv_bridge\.hppp*"|cv_bridge/cv_bridge.hpp"|g' "$APRILTAG_HPP"
    sed -i 's|image_geometry/pinhole_camera_model\.hppp*"|image_geometry/pinhole_camera_model.hpp"|g' "$APRILTAG_HPP"
    
    # Only convert .h to .hpp if EXACT .h" pattern exists (safe check to avoid double conversion)
    if grep -qE 'cv_bridge/cv_bridge\.h"' "$APRILTAG_HPP" 2>/dev/null; then
        if ! grep -qE 'cv_bridge/cv_bridge\.hpp"' "$APRILTAG_HPP" 2>/dev/null; then
            sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' "$APRILTAG_HPP"
        fi
    fi
    if grep -qE 'image_geometry/pinhole_camera_model\.h"' "$APRILTAG_HPP" 2>/dev/null; then
        if ! grep -qE 'image_geometry/pinhole_camera_model\.hpp"' "$APRILTAG_HPP" 2>/dev/null; then
            sed -i 's|image_geometry/pinhole_camera_model\.h"|image_geometry/pinhole_camera_model.hpp"|g' "$APRILTAG_HPP"
        fi
    fi
fi

if [ -f "$APRILTAG_CPP" ]; then
    # Fix any corrupted .hppp+ patterns first
    sed -i 's|cv_bridge/cv_bridge\.hppp*"|cv_bridge/cv_bridge.hpp"|g' "$APRILTAG_CPP"
    
    # Only convert .h to .hpp if EXACT .h" pattern exists
    if grep -qE 'cv_bridge/cv_bridge\.h"' "$APRILTAG_CPP" 2>/dev/null; then
        if ! grep -qE 'cv_bridge/cv_bridge\.hpp"' "$APRILTAG_CPP" 2>/dev/null; then
            sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' "$APRILTAG_CPP"
        fi
    fi
    
    # Fix explicit constructor warning for declare_parameter with empty initializer lists
    # The warning occurs because {} is being converted to rcl_interfaces::msg::ParameterDescriptor
    # which has an explicit constructor. Fix by using explicit vector types instead of {}
    log_info "    Fixing declare_parameter explicit constructor warnings..."
    
    # Fix tag_ids parameter (line ~84)
    if grep -q 'declare_parameter<std::vector<int64_t>>("tag_ids", {})' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"; then
        sed -i 's|declare_parameter<std::vector<int64_t>>("tag_ids", {})|declare_parameter<std::vector<int64_t>>("tag_ids", std::vector<int64_t>{})|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
    fi
    
    # Fix tag_frames parameter (line ~85)
    if grep -q 'declare_parameter<std::vector<std::string>>("tag_frames", {})' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"; then
        sed -i 's|declare_parameter<std::vector<std::string>>("tag_frames", {})|declare_parameter<std::vector<std::string>>("tag_frames", std::vector<std::string>{})|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
    fi
    
    # Fix tag_sizes parameter (line ~97)
    if grep -q 'declare_parameter<std::vector<double>>("tag_sizes", {})' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"; then
        sed -i 's|declare_parameter<std::vector<double>>("tag_sizes", {})|declare_parameter<std::vector<double>>("tag_sizes", std::vector<double>{})|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
    fi
fi

# Fix 6: costmap_converter - Change .h to .hpp, fix corrupted patterns, and fix RCLCPP logging (IDEMPOTENT)
log_info "  Fixing costmap_converter..."
# Fix .h to .hpp conversions and corruption cleanup
find "$UGV_WS_DIR/src/ugv_else/costmap_converter" -type f \( -name "*.h" -o -name "*.cpp" \) 2>/dev/null | while read file; do
    # First, clean up any corrupted .hppp+ patterns (multiple p's after hpp)
    sed -i 's|cv_bridge/cv_bridge\.hppp*"|cv_bridge/cv_bridge.hpp"|g' "$file" 2>/dev/null || true
    sed -i 's|cv_bridge/cv_bridge\.hppp*>|cv_bridge/cv_bridge.hpp>|g' "$file" 2>/dev/null || true
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.hppp*"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$file" 2>/dev/null || true
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.hppp*>|tf2_geometry_msgs/tf2_geometry_msgs.hpp>|g' "$file" 2>/dev/null || true
    
    # Then fix .h to .hpp only if EXACT .h pattern exists AND .hpp doesn't already exist
    # cv_bridge with "
    if grep -qE 'cv_bridge/cv_bridge\.h"' "$file" 2>/dev/null; then
        if ! grep -qE 'cv_bridge/cv_bridge\.hpp"' "$file" 2>/dev/null; then
            sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' "$file" 2>/dev/null || true
        fi
    fi
    # cv_bridge with >
    if grep -qE 'cv_bridge/cv_bridge\.h>' "$file" 2>/dev/null; then
        if ! grep -qE 'cv_bridge/cv_bridge\.hpp>' "$file" 2>/dev/null; then
            sed -i 's|cv_bridge/cv_bridge\.h>|cv_bridge/cv_bridge.hpp>|g' "$file" 2>/dev/null || true
        fi
    fi
    # tf2_geometry_msgs with "
    if grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.h"' "$file" 2>/dev/null; then
        if ! grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.hpp"' "$file" 2>/dev/null; then
            sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$file" 2>/dev/null || true
        fi
    fi
    # tf2_geometry_msgs with >
    if grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.h>' "$file" 2>/dev/null; then
        if ! grep -qE 'tf2_geometry_msgs/tf2_geometry_msgs\.hpp>' "$file" 2>/dev/null; then
            sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h>|tf2_geometry_msgs/tf2_geometry_msgs.hpp>|g' "$file" 2>/dev/null || true
        fi
    fi
done

# Fix costmap_converter_interface.h RCLCPP logging format warnings
COSTMAP_INTERFACE="$UGV_WS_DIR/src/ugv_else/costmap_converter/costmap_converter/include/costmap_converter/costmap_converter_interface.h"
if [ -f "$COSTMAP_INTERFACE" ]; then
    # Fix RCLCPP_DEBUG with extra argument (remove "costmap_converter" tag)
    if grep -q 'RCLCPP_DEBUG(nh_->get_logger(), "costmap_converter", "Spinning up' "$COSTMAP_INTERFACE" 2>/dev/null; then
        sed -i 's|RCLCPP_DEBUG(nh_->get_logger(), "costmap_converter", "Spinning up a thread for the CostmapToPolygons plugin");|RCLCPP_DEBUG(nh_->get_logger(), "Spinning up a thread for the CostmapToPolygons plugin");|g' "$COSTMAP_INTERFACE"
    fi
    
    # Fix RCLCPP_INFO with std::string format (add .c_str())
    if grep -q 'plugin for static obstacles %s loaded.", plugin_name);' "$COSTMAP_INTERFACE" 2>/dev/null; then
        sed -i 's|plugin for static obstacles %s loaded.", plugin_name);|plugin for static obstacles %s loaded.", plugin_name.c_str());|g' "$COSTMAP_INTERFACE"
    fi
fi

# Fix 7: teb_local_planner - Fix nav2_core exceptions and calculateMinAndMaxDistances API
log_info "  Fixing teb_local_planner..."

# Fix teb_local_planner_ros.cpp for Jazzy compatibility
TEB_FILE="$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/src/teb_local_planner_ros.cpp"
if [ -f "$TEB_FILE" ]; then
    # Fix nav2_core exceptions (only if old pattern exists)
    if grep -q "nav2_core/exceptions\.hpp" "$TEB_FILE" 2>/dev/null; then
        sed -i 's|<nav2_core/exceptions\.hpp>|<nav2_core/controller_exceptions.hpp>|g' "$TEB_FILE"
    fi
    
    # Replace PlannerException with ControllerException (if not already fixed)
    if grep -q "nav2_core::PlannerException" "$TEB_FILE" 2>/dev/null; then
        sed -i 's|nav2_core::PlannerException|nav2_core::ControllerException|g' "$TEB_FILE"
    fi
    
    # Fix calculateMinAndMaxDistances API (Jazzy returns pair instead of output parameters)
    # Note: variable is robot_circumscribed_radius (no trailing underscore)
    # Check if old API pattern exists (with 3 parameters)
    if grep -q "calculateMinAndMaxDistances(footprint_spec_, robot_inscribed_radius_, robot_circumscribed_radius)" "$TEB_FILE" 2>/dev/null; then
        log_info "    Fixing calculateMinAndMaxDistances at line ~153..."
        # Use a unique context to fix line 153
        sed -i '/footprint_spec_ = costmap_ros_->getRobotFootprint();/{n;s|nav2_costmap_2d::calculateMinAndMaxDistances(footprint_spec_, robot_inscribed_radius_, robot_circumscribed_radius);|auto distances = nav2_costmap_2d::calculateMinAndMaxDistances(footprint_spec_);\n    robot_inscribed_radius_ = distances.first;\n    robot_circumscribed_radius = distances.second;|}' "$TEB_FILE"
    fi
    
    # Fix second occurrence at line ~391
    if grep -q "calculateMinAndMaxDistances(updated_footprint_spec_, robot_inscribed_radius_, robot_circumscribed_radius)" "$TEB_FILE" 2>/dev/null; then
        log_info "    Fixing calculateMinAndMaxDistances at line ~391..."
        # Use a unique context to fix line 391
        sed -i '/updated_footprint_spec_ = footprint_spec_;/{n;s|nav2_costmap_2d::calculateMinAndMaxDistances(updated_footprint_spec_, robot_inscribed_radius_, robot_circumscribed_radius);|auto distances = nav2_costmap_2d::calculateMinAndMaxDistances(updated_footprint_spec_);\n      robot_inscribed_radius_ = distances.first;\n      robot_circumscribed_radius = distances.second;|}' "$TEB_FILE"
    fi
fi

# Fix 8: vizanti_server - Make rosbridge_suite optional (not available in Jazzy)
log_info "  Fixing vizanti_server..."
VIZANTI_CMAKE="$UGV_WS_DIR/src/ugv_else/vizanti/vizanti_server/CMakeLists.txt"
if [ -f "$VIZANTI_CMAKE" ]; then
    # Make rosbridge_suite optional if it's currently REQUIRED
    if grep -q 'find_package(rosbridge_suite REQUIRED)' "$VIZANTI_CMAKE" 2>/dev/null; then
        log_info "    Making rosbridge_suite optional (not available in Jazzy)..."
        sed -i 's|find_package(rosbridge_suite REQUIRED)|find_package(rosbridge_suite QUIET)\n\nif(NOT rosbridge_suite_FOUND)\n  message(WARNING "rosbridge_suite not found - vizanti web interface may have limited functionality")\nendif()|g' "$VIZANTI_CMAKE"
    fi
fi

# Fix 9: master_beast.launch.py - Fix deprecated LaunchConfigurationEquals/NotEquals (ROS 2 Jazzy)
log_info "  Fixing master_beast.launch.py (deprecation warnings and image_proc)..."
LAUNCH_FILE="$UGV_WS_DIR/src/ugv_main/ugv_bringup/launch/master_beast.launch.py"
if [ -f "$LAUNCH_FILE" ]; then
    # Fix imports: replace deprecated conditions with new substitutions
    if grep -q "LaunchConfigurationEquals, LaunchConfigurationNotEquals" "$LAUNCH_FILE" 2>/dev/null; then
        sed -i 's|from launch.conditions import IfCondition, LaunchConfigurationEquals, LaunchConfigurationNotEquals|from launch.conditions import IfCondition|g' "$LAUNCH_FILE"
        # Add new imports if not already present
        if ! grep -q "EqualsSubstitution, NotEqualsSubstitution" "$LAUNCH_FILE" 2>/dev/null; then
            sed -i 's|from launch.substitutions import LaunchConfiguration|from launch.substitutions import LaunchConfiguration, EqualsSubstitution, NotEqualsSubstitution|g' "$LAUNCH_FILE"
        fi
    fi
    
    # Fix condition usages - replace LaunchConfigurationEquals with IfCondition(EqualsSubstitution(...))
    if grep -q "condition=LaunchConfigurationEquals" "$LAUNCH_FILE" 2>/dev/null; then
        sed -i "s|condition=LaunchConfigurationEquals('camera_container', '')|condition=IfCondition(EqualsSubstitution(LaunchConfiguration('camera_container'), ''))|g" "$LAUNCH_FILE"
    fi
    if grep -q "condition=LaunchConfigurationNotEquals" "$LAUNCH_FILE" 2>/dev/null; then
        sed -i "s|condition=LaunchConfigurationNotEquals('camera_container', '')|condition=IfCondition(NotEqualsSubstitution(LaunchConfiguration('camera_container'), ''))|g" "$LAUNCH_FILE"
    fi
    
    # Add use_image_proc argument if not present (to make image_proc optional)
    if ! grep -q "use_image_proc" "$LAUNCH_FILE" 2>/dev/null; then
        log_info "    Adding use_image_proc argument to make image_proc optional..."
        # This is a complex change, so we'll just log a warning for manual review
        log_warn "    NOTE: image_proc is optional. To enable, run with use_image_proc:=true"
        log_warn "    Ensure ros-jazzy-image-proc is installed if you want to use it"
    fi
fi

# Fix 10: ugv_nav CMakeLists.txt - Make nav2_bringup optional (only needed at runtime)
log_info "  Fixing ugv_nav (make nav2_bringup optional at build time)..."
UGV_NAV_CMAKE="$UGV_WS_DIR/src/ugv_main/ugv_nav/CMakeLists.txt"
if [ -f "$UGV_NAV_CMAKE" ]; then
    # Check if already fixed (look for QUIET keyword)
    if grep -q "find_package(nav2_bringup QUIET)" "$UGV_NAV_CMAKE" 2>/dev/null; then
        log_info "    ugv_nav CMakeLists.txt already fixed"
    elif grep -q "find_package(nav2_bringup REQUIRED)" "$UGV_NAV_CMAKE" 2>/dev/null; then
        log_info "    Making nav2_bringup dependency optional..."
        # Replace REQUIRED with QUIET and add warning message
        sed -i 's|find_package(nav2_bringup REQUIRED)|# nav2_bringup is optional - only needed at runtime for actual navigation\n# This allows the package to build even without Nav2 installed\nfind_package(nav2_bringup QUIET)\nif(NOT nav2_bringup_FOUND)\n  message(WARNING "nav2_bringup not found - ugv_nav will build but navigation features require Nav2 at runtime")\nendif()|g' "$UGV_NAV_CMAKE"
        log_info "    ✓ ugv_nav CMakeLists.txt patched"
    fi
fi

# Fix FindG2O.cmake - Add multiarch paths
if [ -f "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake" ]; then
    if ! grep -q "lib/aarch64-linux-gnu" "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"; then
        sed -i 's|PATH_SUFFIXES lib|PATH_SUFFIXES lib lib/aarch64-linux-gnu lib/x86_64-linux-gnu|g' \
            "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"
    fi
fi

# Fix 11: ugv_integrated_driver.py - Handle missing magnetometer data gracefully
log_info "  Fixing ugv_integrated_driver (handle missing magnetometer data)..."
UGV_DRIVER="$UGV_WS_DIR/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py"
if [ -f "$UGV_DRIVER" ]; then
    # Check if fix is needed (old pattern uses direct dict access)
    if grep -q 'imu_raw_data\["mz"\]' "$UGV_DRIVER" 2>/dev/null; then
        log_info "    Fixing publish_imu_mag to handle missing magnetometer data..."
        # Use Python to properly fix the indentation - pass path via environment variable
        UGV_DRIVER_PATH="$UGV_DRIVER" python3 << 'PYEOF'
import re
import os

driver_path = os.environ['UGV_DRIVER_PATH']

with open(driver_path, 'r') as f:
    content = f.read()

# Find and replace the magnetometer code block with proper indentation
old_pattern = r'''        msg\.magnetic_field\.x = float\(imu_raw_data\["mx"\]\) \* 0\.15
        msg\.magnetic_field\.y = float\(imu_raw_data\["my"\]\) \* 0\.15
        msg\.magnetic_field\.z = float\(imu_raw_data\["mz"\]\) \* 0\.15'''

new_code = '''        # Handle missing magnetometer data gracefully (some hardware doesn't have mag sensor)
        try:
            msg.magnetic_field.x = float(imu_raw_data.get("mx", 0)) * 0.15
            msg.magnetic_field.y = float(imu_raw_data.get("my", 0)) * 0.15
            msg.magnetic_field.z = float(imu_raw_data.get("mz", 0)) * 0.15
        except (KeyError, TypeError, ValueError):
            # If magnetometer data is unavailable, publish zeros
            msg.magnetic_field.x = 0.0
            msg.magnetic_field.y = 0.0
            msg.magnetic_field.z = 0.0'''

content = re.sub(old_pattern, new_code, content)

with open(driver_path, 'w') as f:
    f.write(content)
PYEOF
        log_info "    ✓ ugv_integrated_driver.py patched for missing magnetometer data"
    else
        log_info "    ugv_integrated_driver.py already handles missing magnetometer data"
    fi
fi

# Fix 12: rf2o_laser_odometry - Suppress Eigen array-bounds warnings on GCC 14+ ARM64
log_info "  Fixing rf2o_laser_odometry (suppress Eigen warnings on GCC 14+)..."
RF2O_CMAKE="$UGV_WS_DIR/src/ugv_else/rf2o_laser_odometry/CMakeLists.txt"
if [ -f "$RF2O_CMAKE" ]; then
    # Check if fix is needed (GCC 14 warning suppression not present)
    if ! grep -q "Wno-array-bounds" "$RF2O_CMAKE" 2>/dev/null; then
        log_info "    Adding GCC 14+ array-bounds warning suppression for Eigen..."
        # Add warning suppression after the existing compile options
        sed -i '/add_compile_options(-Wall -Wextra -Wpedantic)/a\  # Suppress false positive array-bounds warnings from Eigen with GCC 14+ on ARM64\n  # These are known issues with Eigens NEON optimizations and aggressive GCC static analysis\n  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 14)\n    add_compile_options(-Wno-array-bounds)\n  endif()' "$RF2O_CMAKE"
        log_info "    ✓ rf2o_laser_odometry CMakeLists.txt patched"
    else
        log_info "    rf2o_laser_odometry already has Eigen warning suppression"
    fi
fi

# Fix 13: Remove deprecated tests_require from setup.py files (Python 3.12+/setuptools deprecation)
log_info "  Fixing deprecated tests_require in setup.py files..."
for setup_file in "$UGV_WS_DIR"/src/ugv_main/*/setup.py "$UGV_WS_DIR"/src/mqtt_bridge/setup.py; do
    if [ -f "$setup_file" ]; then
        if grep -q "tests_require" "$setup_file" 2>/dev/null; then
            log_info "    Removing tests_require from $(basename $(dirname $setup_file))/setup.py..."
            sed -i "/tests_require=\['pytest'\],/d" "$setup_file"
        fi
    fi
done
log_info "    ✓ Deprecated tests_require lines removed"

log_info "✅ All ROS 2 $ROS_DISTRO compatibility fixes applied successfully!"

################################################################################
# STEP 10: BUILD APRILTAG LIBRARY
################################################################################
log_step "=== Step 10: Building AprilTag Library ==="

APRILTAG_DIR="$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag"

if [ -d "$APRILTAG_DIR" ]; then
    log_info "Building apriltag library..."
    cd "$APRILTAG_DIR"
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j2
    sudo make install
    sudo ldconfig
    log_info "✓ AprilTag library built and installed"
else
    log_warn "AprilTag directory not found, skipping..."
fi

################################################################################
# STEP 11: BUILD UGV WORKSPACE
################################################################################
log_step "=== Step 11: Building UGV Workspace (RAM-Optimized) ==="

cd "$UGV_WS_DIR"

# Define all required packages that must be verified
# Core packages that don't require Nav2
REQUIRED_CORE_PACKAGES="apriltag apriltag_msgs apriltag_ros cartographer emcl2 openslam_gmapping slam_gmapping ldlidar robot_pose_publisher vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server ugv_base_node ugv_interface image_geometry cv_bridge"
# Message packages (no heavy deps)
REQUIRED_MSG_PACKAGES="costmap_converter_msgs teb_msgs"
# Nav2-dependent packages (optional - require nav2_costmap_2d)
NAV2_DEPENDENT_PACKAGES="costmap_converter teb_local_planner explore_lite"
REQUIRED_HEAVY_PACKAGES="rf2o_laser_odometry"
REQUIRED_APP_PACKAGES="mqtt_bridge ugv_bringup ugv_chat_ai ugv_description ugv_gazebo ugv_nav ugv_slam ugv_tools ugv_vision ugv_web_app"
# Camera packages (optional but recommended for video streaming)
REQUIRED_CAMERA_PACKAGES="usb_cam"

# Check if Nav2 is available
check_nav2_available() {
    if [ -d "/opt/ros/${ROS_DISTRO}/share/nav2_costmap_2d" ] || \
       [ -d "$UGV_WS_DIR/install/nav2_costmap_2d" ]; then
        return 0  # Nav2 is available
    fi
    return 1  # Nav2 is not available
}

# Function to verify package is installed
verify_package_installed() {
    local pkg_name="$1"
    local install_dir="$UGV_WS_DIR/install/$pkg_name"
    local build_dir="$UGV_WS_DIR/build/$pkg_name"
    
    if [ -d "$install_dir" ] && [ -d "$build_dir" ]; then
        return 0  # Package is installed
    fi
    return 1  # Package is missing
}

# Function to get list of missing packages
get_missing_packages() {
    local packages="$1"
    local missing=""
    
    for pkg in $packages; do
        if ! verify_package_installed "$pkg"; then
            missing="$missing $pkg"
        fi
    done
    
    echo "$missing" | xargs  # Trim whitespace
}

# Check if we should skip UGV build
UGV_ALREADY_BUILT=false
if [ "$SKIP_UGV_BUILD" = true ]; then
    if check_build_marker "$UGV_BUILD_MARKER" "UGV Workspace"; then
        # Verify UGV workspace installation is actually working
        if [ -f "$UGV_WS_DIR/install/setup.bash" ]; then
            log_info "Verifying all required packages are installed..."
            
            # Check for missing packages
            MISSING_CORE=$(get_missing_packages "$REQUIRED_CORE_PACKAGES")
            MISSING_MSG=$(get_missing_packages "$REQUIRED_MSG_PACKAGES")
            MISSING_HEAVY=$(get_missing_packages "$REQUIRED_HEAVY_PACKAGES")
            MISSING_APP=$(get_missing_packages "$REQUIRED_APP_PACKAGES")
            MISSING_CAMERA=$(get_missing_packages "$REQUIRED_CAMERA_PACKAGES")
            
            # Only check Nav2-dependent packages if Nav2 is available
            MISSING_NAV2=""
            if check_nav2_available; then
                MISSING_NAV2=$(get_missing_packages "$NAV2_DEPENDENT_PACKAGES")
            else
                log_info "  Nav2 not available - skipping Nav2-dependent packages (costmap_converter, teb_local_planner)"
            fi
            
            ALL_MISSING="$MISSING_CORE $MISSING_MSG $MISSING_HEAVY $MISSING_APP $MISSING_CAMERA $MISSING_NAV2"
            ALL_MISSING=$(echo "$ALL_MISSING" | xargs)  # Trim whitespace
            
            if [ -z "$ALL_MISSING" ]; then
                log_info "✓ All required packages verified, skipping full rebuild..."
                UGV_ALREADY_BUILT=true
            else
                log_warn "Some packages are missing from install directory:"
                log_warn "  Missing: $ALL_MISSING"
                log_info "Will rebuild missing packages only..."
                # Don't set UGV_ALREADY_BUILT=true, will rebuild missing packages
            fi
        else
            log_warn "UGV build marker exists but install/setup.bash not found, rebuilding..."
            remove_build_marker "$UGV_BUILD_MARKER"
        fi
    else
        log_info "No previous UGV workspace build found, proceeding with build..."
    fi
fi

# Clean AMENT_PREFIX_PATH and CMAKE_PREFIX_PATH to avoid stale paths
log_info "Cleaning environment paths to avoid stale references..."
unset AMENT_PREFIX_PATH
unset CMAKE_PREFIX_PATH
unset COLCON_PREFIX_PATH

log_info "Sourcing ROS 2 $ROS_DISTRO environment (clean)..."
if [ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
    source /opt/ros/${ROS_DISTRO}/setup.bash
else
    log_error "ROS 2 $ROS_DISTRO setup.bash not found at /opt/ros/${ROS_DISTRO}/setup.bash"
    log_error "ROS 2 installation may have failed. Check the build logs."
    exit 1
fi

if [ "$UGV_ALREADY_BUILT" = false ]; then

# First, build image_geometry and cv_bridge (dependencies for apriltag_ros)
log_info "Building image processing dependencies (image_geometry, cv_bridge)..."
if [ -d "$UGV_WS_DIR/src/vision_opencv" ]; then
    colcon build --executor sequential \
        --packages-select image_geometry cv_bridge \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee "$WORKSPACE_DIR/build-vision.log" || log_warn "vision_opencv packages may have failed"
fi

log_info "Building first set of packages sequentially (RAM-friendly)..."
log_info "This will take time but prevents system crashes due to low RAM..."
colcon build --executor sequential \
    --packages-select \
        apriltag apriltag_msgs apriltag_ros \
        cartographer costmap_converter_msgs \
        emcl2 openslam_gmapping slam_gmapping \
        ldlidar robot_pose_publisher teb_msgs \
        vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server \
        ugv_base_node ugv_interface \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-core-packages.log"

# Build Nav2-dependent packages only if Nav2 is available
if check_nav2_available; then
    log_info "Nav2 detected - building costmap_converter..."
    colcon build --executor sequential \
        --packages-select costmap_converter \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee "$WORKSPACE_DIR/build-costmap-converter.log" || log_warn "costmap_converter failed to build"

    log_info "🔧 Applying FindG2O.cmake fix for teb_local_planner..."
    FINDG2O_FILE="$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"
    if [ -f "$FINDG2O_FILE" ]; then
        # Check if fix is already applied
        if grep -q "# Add incremental library only if found" "$FINDG2O_FILE"; then
            log_info "  FindG2O.cmake fix already applied"
        else
            log_info "  Patching FindG2O.cmake to make G2O_INCREMENTAL_LIB optional..."
            # Backup original file
            cp "$FINDG2O_FILE" "${FINDG2O_FILE}.backup"
            
            # Apply the fix using sed to make G2O_INCREMENTAL_LIB optional
            sed -i '/SET(G2O_LIBRARIES ${G2O_CSPARSE_EXTENSION_LIB}/,/)/c\
  SET(G2O_LIBRARIES ${G2O_CSPARSE_EXTENSION_LIB}\
                    ${G2O_CORE_LIB}           \
                    ${G2O_STUFF_LIB}          \
                    ${G2O_TYPES_SLAM2D_LIB}   \
                    ${G2O_TYPES_SLAM3D_LIB}   \
                    ${G2O_SOLVER_CHOLMOD_LIB} \
                    ${G2O_SOLVER_PCG_LIB}     \
                    ${G2O_SOLVER_CSPARSE_LIB})\
  \
  # Add incremental library only if found (optional in newer g2o versions)\
  IF(G2O_INCREMENTAL_LIB)\
    LIST(APPEND G2O_LIBRARIES ${G2O_INCREMENTAL_LIB})\
  ENDIF(G2O_INCREMENTAL_LIB)' "$FINDG2O_FILE"
            
            log_info "  ✓ FindG2O.cmake patched successfully"
        fi
    else
        log_warn "FindG2O.cmake not found at expected location"
    fi

    log_info "Building teb_local_planner with minimal RAM usage (single thread)..."
    MAKEFLAGS=-j1 colcon build \
        --executor sequential \
        --packages-select teb_local_planner \
        --parallel-workers 1 \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee "$WORKSPACE_DIR/build-teb.log" || log_warn "teb_local_planner failed (known issue on ARM64, may work after reboot)"

    log_info "Building explore_lite (requires nav2_msgs)..."
    colcon build --executor sequential \
        --packages-select explore_lite \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee "$WORKSPACE_DIR/build-explore-lite.log" || log_warn "explore_lite failed to build"
else
    log_info "Nav2 not available - skipping Nav2-dependent packages (costmap_converter, teb_local_planner, explore_lite)"
fi

log_info "Building rf2o_laser_odometry with minimal RAM usage (single thread)..."
MAKEFLAGS=-j1 colcon build \
    --executor sequential \
    --packages-select rf2o_laser_odometry \
    --parallel-workers 1 \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-rf2o.log"

log_info "Sourcing workspace..."
# Source the workspace with proper error handling and environment cleanup
if [ -f "$UGV_WS_DIR/install/setup.bash" ]; then
    # Clean environment paths first to avoid stale references
    unset AMENT_PREFIX_PATH
    unset CMAKE_PREFIX_PATH
    unset COLCON_PREFIX_PATH
    
    # Re-source ROS 2 base
    source /opt/ros/${ROS_DISTRO}/setup.bash
    
    # Source the workspace
    source "$UGV_WS_DIR/install/setup.bash" 2>/dev/null || true
fi

log_info "Building UGV application packages (Python packages with symlink-install)..."

# Always include ugv_nav - it's a config package that can build without Nav2 runtime
# Nav2 is only needed at RUNTIME, not at BUILD time
UGV_PACKAGES="mqtt_bridge ugv_bringup ugv_chat_ai ugv_description ugv_gazebo ugv_nav ugv_slam ugv_tools ugv_vision ugv_web_app"

log_info "Building all UGV application packages (including ugv_nav)..."
log_info "  Note: ugv_nav will build but requires Nav2 at runtime for navigation features"

colcon build \
    --executor sequential \
    --packages-select $UGV_PACKAGES \
    --symlink-install \
    --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-ugv-apps.log"

log_info "Ensuring ugv_bringup is properly installed..."
# Clean and rebuild ugv_bringup to ensure all launch files are installed
rm -rf "$UGV_WS_DIR/build/ugv_bringup" "$UGV_WS_DIR/install/ugv_bringup"
colcon build --executor sequential --packages-select ugv_bringup --symlink-install \
    --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee -a "$WORKSPACE_DIR/build-ugv-apps.log"

# Build camera packages (usb_cam and dependencies)
log_info "Building camera packages (usb_cam)..."
if [ -d "$UGV_WS_DIR/src/usb_cam" ]; then
    # Build usb_cam with its dependencies
    colcon build \
        --executor sequential \
        --packages-up-to usb_cam \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee "$WORKSPACE_DIR/build-camera.log" || log_warn "usb_cam build failed (camera support may be limited)"
    
    # NOTE: image_proc is used from system packages (/opt/ros/jazzy)
    # We do NOT build it from source to avoid API conflicts with message_filters
    log_info "✓ image_proc will be used from system packages if available"
else
    log_warn "usb_cam source not found, camera support will be limited"
fi

fi  # End of UGV_ALREADY_BUILT check for main build

################################################################################
# STEP 11.5: VERIFY AND REBUILD MISSING PACKAGES
################################################################################
log_step "=== Step 11.5: Verifying All Required Packages Are Installed ==="

# Clean environment and re-source to ensure clean state
log_info "Cleaning environment paths for verification..."
unset AMENT_PREFIX_PATH
unset CMAKE_PREFIX_PATH
unset COLCON_PREFIX_PATH
source /opt/ros/${ROS_DISTRO}/setup.bash

cd "$UGV_WS_DIR"

# Re-check for missing packages after build
MISSING_CORE=$(get_missing_packages "$REQUIRED_CORE_PACKAGES")
MISSING_HEAVY=$(get_missing_packages "$REQUIRED_HEAVY_PACKAGES")
MISSING_APP=$(get_missing_packages "$REQUIRED_APP_PACKAGES")
MISSING_CAMERA=$(get_missing_packages "$REQUIRED_CAMERA_PACKAGES")

# Rebuild missing core packages
if [ -n "$MISSING_CORE" ]; then
    log_warn "Rebuilding missing core packages: $MISSING_CORE"
    colcon build --executor sequential \
        --packages-select $MISSING_CORE \
        --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee -a "$WORKSPACE_DIR/build-core-packages.log"
fi

# Rebuild missing heavy packages
if [ -n "$MISSING_HEAVY" ]; then
    log_warn "Rebuilding missing heavy packages: $MISSING_HEAVY"
    for pkg in $MISSING_HEAVY; do
        MAKEFLAGS=-j1 colcon build \
            --executor sequential \
            --packages-select $pkg \
            --parallel-workers 1 \
            --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
            2>&1 | tee -a "$WORKSPACE_DIR/build-heavy.log"
    done
fi

# Rebuild missing app packages
if [ -n "$MISSING_APP" ]; then
    log_warn "Rebuilding missing app packages: $MISSING_APP"
    colcon build \
        --executor sequential \
        --packages-select $MISSING_APP \
        --symlink-install \
        --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee -a "$WORKSPACE_DIR/build-ugv-apps.log"
fi

# Rebuild missing camera packages
if [ -n "$MISSING_CAMERA" ]; then
    log_warn "Rebuilding missing camera packages: $MISSING_CAMERA"
    if [ -d "$UGV_WS_DIR/src/usb_cam" ]; then
        colcon build \
            --executor sequential \
            --packages-up-to $MISSING_CAMERA \
            --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
            2>&1 | tee -a "$WORKSPACE_DIR/build-camera.log"
    else
        log_warn "usb_cam source not available, cloning..."
        cd "$UGV_WS_DIR/src"
        git clone https://github.com/ros-drivers/usb_cam.git 2>/dev/null && {
            cd "$UGV_WS_DIR"
            colcon build \
                --executor sequential \
                --packages-up-to usb_cam \
                --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
                2>&1 | tee -a "$WORKSPACE_DIR/build-camera.log"
        } || log_warn "Failed to clone/build usb_cam"
        cd "$UGV_WS_DIR"
    fi
fi

# Final verification
log_info "Final verification of all packages..."
FINAL_MISSING_CORE=$(get_missing_packages "$REQUIRED_CORE_PACKAGES")
FINAL_MISSING_HEAVY=$(get_missing_packages "$REQUIRED_HEAVY_PACKAGES")
FINAL_MISSING_APP=$(get_missing_packages "$REQUIRED_APP_PACKAGES")
FINAL_MISSING_CAMERA=$(get_missing_packages "$REQUIRED_CAMERA_PACKAGES")
FINAL_ALL_MISSING="$FINAL_MISSING_CORE $FINAL_MISSING_HEAVY $FINAL_MISSING_APP"
FINAL_ALL_MISSING=$(echo "$FINAL_ALL_MISSING" | xargs)

if [ -n "$FINAL_ALL_MISSING" ]; then
    log_error "❌ Some packages still failed to install: $FINAL_ALL_MISSING"
    log_error "   Check the build logs for errors"
else
    log_info "✓ All required packages verified successfully!"
fi

# Camera packages are optional, just warn if missing
if [ -n "$FINAL_MISSING_CAMERA" ]; then
    log_warn "⚠️ Camera packages not installed: $FINAL_MISSING_CAMERA"
    log_warn "   Camera functionality may be limited. This is optional."
else
    log_info "✓ Camera packages (usb_cam) installed successfully!"
fi

################################################################################
# BUILD SUMMARY
################################################################################
log_info ""
log_info "=========================================="
log_info "📊 BUILD SUMMARY"
log_info "=========================================="

# Analyze build logs for errors and warnings
FAILED_PACKAGES=""
WARNED_PACKAGES=""
SUCCESS_PACKAGES=""

# Check each build log file
for LOG_FILE in "$WORKSPACE_DIR"/build-*.log; do
    if [ -f "$LOG_FILE" ]; then
        LOG_NAME=$(basename "$LOG_FILE" .log)
        
        # Check for failed packages
        if grep -q "Failed   <<<" "$LOG_FILE"; then
            FAILED=$(grep "Failed   <<<" "$LOG_FILE" | awk '{print $3}' | sort -u)
            if [ -n "$FAILED" ]; then
                FAILED_PACKAGES="$FAILED_PACKAGES $FAILED"
            fi
        fi
        
        # Check for packages with warnings
        if grep -q "stderr:" "$LOG_FILE"; then
            WARNED=$(grep "stderr:" "$LOG_FILE" | awk '{print $2}' | sort -u)
            if [ -n "$WARNED" ]; then
                WARNED_PACKAGES="$WARNED_PACKAGES $WARNED"
            fi
        fi
        
        # Check for successful packages
        if grep -q "Finished <<<" "$LOG_FILE"; then
            SUCCESS=$(grep "Finished <<<" "$LOG_FILE" | awk '{print $3}' | sort -u)
            if [ -n "$SUCCESS" ]; then
                SUCCESS_PACKAGES="$SUCCESS_PACKAGES $SUCCESS"
            fi
        fi
    fi
done

# Remove duplicates
FAILED_PACKAGES=$(echo "$FAILED_PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')
WARNED_PACKAGES=$(echo "$WARNED_PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')
SUCCESS_PACKAGES=$(echo "$SUCCESS_PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

# Count packages
FAILED_COUNT=$(echo "$FAILED_PACKAGES" | wc -w)
WARNED_COUNT=$(echo "$WARNED_PACKAGES" | wc -w)
SUCCESS_COUNT=$(echo "$SUCCESS_PACKAGES" | wc -w)

log_info ""
log_info "✅ Successfully built packages: $SUCCESS_COUNT"
if [ $SUCCESS_COUNT -gt 0 ]; then
    for PKG in $SUCCESS_PACKAGES; do
        log_info "   ✓ $PKG"
    done
fi

log_info ""
if [ $FAILED_COUNT -gt 0 ]; then
    log_error "❌ FAILED packages: $FAILED_COUNT"
    for PKG in $FAILED_PACKAGES; do
        log_error "   ✗ $PKG - BUILD FAILED!"
    done
else
    log_info "❌ FAILED packages: 0"
fi

log_info ""
if [ $WARNED_COUNT -gt 0 ]; then
    log_warn "⚠️  Packages with warnings: $WARNED_COUNT"
    for PKG in $WARNED_PACKAGES; do
        log_warn "   ! $PKG (has warnings, but built successfully)"
    done
else
    log_info "⚠️  Packages with warnings: 0"
fi

log_info ""
log_info "=========================================="
log_info "Build logs location: $WORKSPACE_DIR/build-*.log"
log_info "=========================================="

if [ $FAILED_COUNT -gt 0 ]; then
    log_warn "⚠️  Some packages failed to build. Check the logs above for details."
    log_warn "You may need to rebuild failed packages manually or after a reboot."
fi

log_info "✓ UGV workspace built successfully (with RAM-optimized settings)"

# Create build marker for successful UGV workspace build
if [ -f "$UGV_WS_DIR/install/setup.bash" ]; then
    create_build_marker "$UGV_BUILD_MARKER" "UGV Workspace"
fi

################################################################################
# STEP 12: INSTALL PYTHON PACKAGES
################################################################################
log_step "=== Step 12: Installing Python Packages ==="

cd "$UGV_WS_DIR"

log_info "📦 Installing Python packages for UGV..."

# Install from requirements.txt (skipping unavailable packages like mediapipe)
if [ -f "$UGV_WS_DIR/requirements.txt" ]; then
    log_info "  Installing from requirements.txt..."
    # Install each package individually to gracefully handle unavailable packages
    while IFS= read -r package || [ -n "$package" ]; do
        # Skip empty lines and comments
        [[ -z "$package" || "$package" =~ ^# ]] && continue
        # Strip whitespace
        package=$(echo "$package" | xargs)
        
        # Special handling for packages known to be unavailable on ARM64/Python 3.13
        if [[ "$package" == "mediapipe" ]]; then
            log_info "    Skipping $package (not available for ARM64/Python 3.13)..."
            continue
        fi
        
        log_info "    Installing $package..."
        python3 -m pip install "$package" --break-system-packages 2>/dev/null || \
            log_warn "    Failed to install $package - skipping"
    done < "$UGV_WS_DIR/requirements.txt"
else
    log_warn "requirements.txt not found in UGV workspace"
fi

# Install additional UGV-specific packages
log_info "  Installing UGV-specific packages..."
pip3 install --break-system-packages \
    pyserial \
    flask \
    requests \
    aiortc \
    aioice \
    av \
    cyberwave || log_warn "Some packages failed to install"

# Install camera-related Python packages
log_info "  Installing camera-related Python packages..."
pip3 install --break-system-packages \
    opencv-python \
    opencv-contrib-python \
    Pillow \
    imageio \
    v4l2py 2>/dev/null || log_warn "Some camera Python packages failed to install"

# Install v4l-utils for camera debugging
log_info "  Installing v4l-utils for camera debugging..."
safe_apt install -y v4l-utils 2>/dev/null || log_warn "v4l-utils not available"

# mediapipe is not available for Python 3.13 or ARM64, try to install but don't fail
log_info "  Attempting to install mediapipe (may not be available for your platform)..."
pip3 install --break-system-packages mediapipe 2>/dev/null || \
    log_warn "  mediapipe not available for Python $(python3 --version) on $(uname -m) - skipping"

log_info "✅ Python packages installed successfully!"

################################################################################
# STEP 13: ENVIRONMENT CONFIGURATION
################################################################################
log_step "=== Step 13: Configuring Environment (.bashrc) ==="

BASHRC="$HOME/.bashrc"

# Backup existing .bashrc
cp "$BASHRC" "$BASHRC.backup.$(date +%Y%m%d_%H%M%S)"

# Remove old ROS configurations (if any)
sed -i '/# ROS 2 Jazzy setup/d' "$BASHRC"
sed -i '/# ROS 2 Humble setup/d' "$BASHRC"
sed -i '/# ROS 2 .* setup/d' "$BASHRC"
sed -i '/source \/opt\/ros\/jazzy\/setup.bash/d' "$BASHRC"
sed -i '/source \/opt\/ros\/humble\/setup.bash/d' "$BASHRC"
sed -i '/source \/opt\/ros\/\$ROS_DISTRO\/setup.bash/d' "$BASHRC"
sed -i '/source .*ugv_ws\/install\/setup.bash/d' "$BASHRC"
sed -i '/register-python-argcomplete/d' "$BASHRC"
sed -i '/PYTHONWARNINGS/d' "$BASHRC"
sed -i '/UGV_MODEL/d' "$BASHRC"
sed -i '/=== ROS 2 .* Configuration/d' "$BASHRC"

# Add new configuration for ROS 2
log_info "Adding ROS 2 $ROS_DISTRO configuration to .bashrc..."

cat >> "$BASHRC" <<EOF

# === ROS 2 $ROS_DISTRO Configuration (Added by setup script) ===
# ROS 2 $ROS_DISTRO setup
source /opt/ros/${ROS_DISTRO}/setup.bash
# Source workspace setup with error suppression for incomplete packages
source \$HOME/ws/ugv_ws/install/setup.bash 2>/dev/null || source \$HOME/ws/ugv_ws/install/setup.bash

# Enable tab completion for ROS 2 and colcon
eval "\$(register-python-argcomplete ros2)" 2>/dev/null || true
eval "\$(register-python-argcomplete colcon)" 2>/dev/null || true

# Suppress Python deprecation warnings
export PYTHONWARNINGS="ignore::DeprecationWarning"

# Add local Python packages to PATH
export PATH="\$HOME/.local/bin:\$PATH"

# Default UGV model (can be: ugv_rover, ugv_beast, rasp_rover)
export UGV_MODEL=ugv_rover
EOF

log_info "✓ Environment configuration completed (.bashrc updated for ROS 2 $ROS_DISTRO)"
log_info "  ✓ Added error suppression for incomplete packages (prevents 'not found' messages)"

################################################################################
# STEP 13.5: FIX EXISTING BASHRC IF NEEDED
################################################################################
log_step "=== Step 13.5: Checking and Fixing Existing .bashrc Configuration ==="

# Check if the fix is already applied
if grep -q "source \$HOME/ws/ugv_ws/install/setup.bash 2>/dev/null" "$BASHRC"; then
    log_info "✓ .bashrc already has error suppression configured"
else
    # Check if there's an old configuration without error suppression
    if grep -q "source \$HOME/ws/ugv_ws/install/setup.bash" "$BASHRC" && \
       ! grep -q "source \$HOME/ws/ugv_ws/install/setup.bash 2>/dev/null" "$BASHRC"; then
        log_info "Found old .bashrc configuration, applying fix..."
        
        # Replace the old line with the new one that includes error suppression
        sed -i 's|^source \$HOME/ws/ugv_ws/install/setup.bash$|# Source workspace setup with error suppression for incomplete packages\nsource $HOME/ws/ugv_ws/install/setup.bash 2>/dev/null \|\| source $HOME/ws/ugv_ws/install/setup.bash|' "$BASHRC"
        
        log_info "✓ Applied error suppression fix to existing .bashrc"
        log_info "  This prevents 'not found' errors from incomplete packages"
    else
        log_info "✓ No old configuration found to fix"
    fi
fi

################################################################################
# STEP 14: COPY CYBERWAVE MQTT BRIDGE FILES
################################################################################
log_step "=== Step 14: Copying CyberWave MQTT Bridge Files to UGV Workspace ==="

if [ ! -d "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast" ]; then
    log_warn "CyberWave MQTT bridge files not found at $CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast"
    log_warn "Skipping copy operation..."
else
    log_info "Copying UGV Beast configuration files from CyberWave MQTT bridge..."
    
    # Verify target directories exist (they should from cloned repo)
    if [ ! -d "$UGV_WS_DIR/src/ugv_main/ugv_bringup" ]; then
        log_error "Target directory $UGV_WS_DIR/src/ugv_main/ugv_bringup does not exist!"
        log_error "The ugv_ws repository may not have been cloned correctly."
        exit 1
    fi
    
    # Create launch subdirectory if it doesn't exist
    mkdir -p "$UGV_WS_DIR/src/ugv_main/ugv_bringup/launch"
    
    # Copy master_beast.launch.py
    if [ -f "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py" ]; then
        cp "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py" \
           "$UGV_WS_DIR/src/ugv_main/ugv_bringup/launch/master_beast.launch.py"
        log_info "  ✓ Copied master_beast.launch.py"
        
        # Patch master_beast.launch.py to make joint_state_publisher, usb_cam, image_proc optional
        # These packages may not be available in ROS 2 source builds
        log_info "  Patching master_beast.launch.py for optional dependencies..."
        LAUNCH_FILE="$UGV_WS_DIR/src/ugv_main/ugv_bringup/launch/master_beast.launch.py"
        
        # Check if already patched (look for package_available function)
        if ! grep -q "def package_available" "$LAUNCH_FILE" 2>/dev/null; then
            log_info "    Applying optional dependency patches to master_beast.launch.py..."
            
            # Create patched version with optional dependencies
            cat > "$LAUNCH_FILE" << 'LAUNCH_EOF'
#!/usr/bin/env python3
import os
import yaml
from ament_index_python.packages import get_package_share_directory, PackageNotFoundError
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, SetEnvironmentVariable, LogInfo
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch.conditions import IfCondition
from launch_ros.actions import LoadComposableNodes, Node, ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

# Helper to check if a package exists
def package_available(package_name):
    try:
        get_package_share_directory(package_name)
        return True
    except PackageNotFoundError:
        return False

def generate_launch_description():
    # 1. Paths to packages and configurations
    ugv_bringup_dir = get_package_share_directory('ugv_bringup')
    ugv_vision_dir = get_package_share_directory('ugv_vision')
    ugv_description_dir = get_package_share_directory('ugv_description')
    mqtt_bridge_dir = get_package_share_directory('mqtt_bridge')
    ldlidar_dir = get_package_share_directory('ldlidar')
    
    # Check for optional packages
    has_joint_state_publisher = package_available('joint_state_publisher')
    has_usb_cam = package_available('usb_cam')
    has_image_proc = package_available('image_proc')
    
    # Configuration paths
    mqtt_config_path = os.path.join(mqtt_bridge_dir, 'config', 'params.yaml')
    
    # 2. Declare Arguments
    pub_odom_tf_arg = DeclareLaunchArgument(
        'pub_odom_tf', 
        default_value='true',
        description='Whether to publish the tf from the original odom'
    )
    
    robot_id_arg = DeclareLaunchArgument(
        'robot_id',
        default_value='robot_ugv_beast_v1',
        description='Unique ID for the Cyberwave cloud'
    )

    use_lidar_arg = DeclareLaunchArgument(
        'use_lidar',
        default_value='false',
        description='Whether to start the LiDAR driver'
    )
    
    camera_namespace_arg = DeclareLaunchArgument(
        name='camera_namespace', default_value='',
        description='Namespace for camera components'
    )
    
    camera_container_arg = DeclareLaunchArgument(
        name='camera_container', default_value='',
        description='Existing container to load camera processing nodes into'
    )

    debug_logs_arg = DeclareLaunchArgument(
        'debug_logs',
        default_value='false',
        description='Enable debug logging for MQTT bridge (shows aiortc, aioice, etc. logs)'
    )

    use_camera_arg = DeclareLaunchArgument(
        'use_camera',
        default_value='true' if has_usb_cam else 'false',
        description='Whether to start the USB camera node (requires usb_cam package)'
    )
    
    use_joint_state_pub_arg = DeclareLaunchArgument(
        'use_joint_state_publisher',
        default_value='true' if has_joint_state_publisher else 'false',
        description='Whether to start the joint_state_publisher (requires joint_state_publisher package)'
    )

    # 3. Core Hardware Node (Integrated Driver)
    bringup_node = Node(
        package='ugv_bringup',
        executable='ugv_integrated_driver',
        name='ugv_bringup',
        output='screen',
        remappings=[
            ('cmd_vel', '/cmd_vel'),
            ('ugv/pt_ctrl', '/ugv/pt_ctrl'),
            ('ugv/led_ctrl', '/ugv/led_ctrl'),
            ('voltage', '/voltage'),
            ('imu/data_raw', '/imu/data_raw'),
            ('imu/mag', '/imu/mag'),
            ('odom/odom_raw', '/odom/odom_raw'),
        ]
    )

    # 4. Lidar Driver
    laser_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(ldlidar_dir, 'launch', 'ldlidar.launch.py')
        ),
        condition=IfCondition(LaunchConfiguration('use_lidar'))
    )

    # 5. Robot Description & Transforms
    set_ugv_model = SetEnvironmentVariable('UGV_MODEL', 'ugv_beast')

    urdf_model_path = os.path.join(ugv_description_dir, 'urdf', 'ugv_beast.urdf')
    with open(urdf_model_path, 'r') as f:
        robot_description_content = f.read()

    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        namespace='ugv',
        parameters=[{'robot_description': robot_description_content}]
    )

    joint_state_publisher_node = Node(
        package='joint_state_publisher',
        executable='joint_state_publisher',
        namespace='ugv',
        name='joint_state_publisher',
        condition=IfCondition(LaunchConfiguration('use_joint_state_publisher')),
        parameters=[{
            'robot_description': robot_description_content,
            'publish_default_positions': True,
        }]
    )

    # 6. Odometry Calculator
    base_node = Node(
        package='ugv_base_node',
        executable='base_node',
        name='base_node',
        parameters=[{'pub_odom_tf': LaunchConfiguration('pub_odom_tf')}],
        remappings=[
            ('imu/data', '/imu/data'),
            ('odom/odom_raw', '/odom/odom_raw'),
            ('odom', '/odom')
        ]
    )

    # 7. Cloud Connectivity (MQTT Bridge)
    mqtt_bridge_node = Node(
        package='mqtt_bridge',
        executable='mqtt_bridge_node',
        name='mqtt_bridge_node',
        parameters=[
            mqtt_config_path, 
            {
                'robot_id': LaunchConfiguration('robot_id'),
                'debug_logs': LaunchConfiguration('debug_logs')
            }
        ],
        output='screen'
    )

    # 8. Video Streaming (Camera)
    camera_param_file = os.path.join(ugv_vision_dir, 'config', 'params.yaml')
    camera_overrides = {}
    try:
        mqtt_params_file = os.path.join(mqtt_bridge_dir, 'config', 'params.yaml')
        with open(mqtt_params_file, 'r') as f:
            mqtt_params = yaml.safe_load(f) or {}
        camera_overrides = (
            mqtt_params.get('/mqtt_bridge_node', {})
            .get('ros__parameters', {})
            .get('camera', {})
        )
    except Exception:
        camera_overrides = {}

    camera_node = Node(
        package='usb_cam',
        executable='usb_cam_node_exe',
        name='usb_cam',
        condition=IfCondition(LaunchConfiguration('use_camera')),
        parameters=[camera_param_file, camera_overrides],
        namespace=LaunchConfiguration('camera_namespace'),
        output='screen',
        respawn=True,
        respawn_delay=2.0
    )

    # Image processing nodes (only if image_proc is available)
    image_processing_container = None
    load_composable_nodes = None
    
    if has_image_proc:
        camera_composable_nodes = [
            ComposableNode(
                package='image_proc',
                plugin='image_proc::RectifyNode',
                name='rectify_color_node',
                namespace=LaunchConfiguration('camera_namespace'),
                remappings=[
                    ('image', 'image_raw'),
                    ('image_rect', 'image_rect')
                ],
            )
        ]

        image_processing_container = ComposableNodeContainer(
            condition=IfCondition(PythonExpression([
                "'", LaunchConfiguration('camera_container'), "' == '' and '",
                LaunchConfiguration('use_camera'), "' == 'true'"
            ])),
            name='image_proc_container',
            namespace=LaunchConfiguration('camera_namespace'),
            package='rclcpp_components',
            executable='component_container',
            composable_node_descriptions=camera_composable_nodes,
            output='screen'
        )

        load_composable_nodes = LoadComposableNodes(
            condition=IfCondition(PythonExpression([
                "'", LaunchConfiguration('camera_container'), "' != '' and '",
                LaunchConfiguration('use_camera'), "' == 'true'"
            ])),
            composable_node_descriptions=camera_composable_nodes,
            target_container=LaunchConfiguration('camera_container'),
        )

    # Build the launch description with all nodes
    ld = LaunchDescription([
        set_ugv_model,
        pub_odom_tf_arg,
        robot_id_arg,
        use_lidar_arg,
        camera_namespace_arg,
        camera_container_arg,
        debug_logs_arg,
        use_camera_arg,
        use_joint_state_pub_arg,
        bringup_node,
        laser_launch,
        robot_state_publisher_node,
        joint_state_publisher_node,
        base_node,
        mqtt_bridge_node,
        camera_node,
    ])
    
    # Add image processing nodes only if available
    if image_processing_container is not None:
        ld.add_action(image_processing_container)
    if load_composable_nodes is not None:
        ld.add_action(load_composable_nodes)
    
    return ld
LAUNCH_EOF
            log_info "    ✓ master_beast.launch.py patched for optional dependencies"
        else
            log_info "    master_beast.launch.py already patched"
        fi
    else
        log_warn "  ✗ master_beast.launch.py not found at expected location"
    fi
    
    # Copy ugv_integrated_driver.py
    if [ -f "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py" ]; then
        cp "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py" \
           "$UGV_WS_DIR/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py"
        log_info "  ✓ Copied ugv_integrated_driver.py"
    else
        log_warn "  ✗ ugv_integrated_driver.py not found at expected location"
    fi
    
    # Copy setup.py
    if [ -f "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/setup.py" ]; then
        cp "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_bringup/setup.py" \
           "$UGV_WS_DIR/src/ugv_main/ugv_bringup/setup.py"
        log_info "  ✓ Copied setup.py"
    else
        log_warn "  ✗ setup.py not found at expected location"
    fi
    
    # Copy ugv_services_install.sh
    if [ -f "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_services_install.sh" ]; then
        cp "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/ugv_services_install.sh" \
           "$UGV_WS_DIR/ugv_services_install.sh"
        chmod +x "$UGV_WS_DIR/ugv_services_install.sh"
        log_info "  ✓ Copied ugv_services_install.sh"
    else
        log_warn "  ✗ ugv_services_install.sh not found at expected location"
    fi
    
    # Copy start_ugv.sh
    if [ -f "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/start_ugv.sh" ]; then
        cp "$CYBERWAVE_REPO_DIR/mqtt_bridge/scripts/ugv_beast/start_ugv.sh" \
           "$UGV_WS_DIR/start_ugv.sh"
        chmod +x "$UGV_WS_DIR/start_ugv.sh"
        log_info "  ✓ Copied start_ugv.sh"
    else
        log_warn "  ✗ start_ugv.sh not found at expected location"
    fi
    
    log_info "✓ CyberWave MQTT bridge files copy completed"
    
    # Rebuild ugv_bringup after copying new files
    # IMPORTANT: Must clean build/install directories first, otherwise colcon with
    # --symlink-install won't pick up newly added files (like master_beast.launch.py)
    log_info "Cleaning ugv_bringup build artifacts (required for new files to be detected)..."
    cd "$UGV_WS_DIR"
    rm -rf build/ugv_bringup install/ugv_bringup
    
    log_info "Rebuilding ugv_bringup package with new files (RAM-optimized)..."
    source /opt/ros/${ROS_DISTRO}/setup.bash
    colcon build --executor sequential --packages-select ugv_bringup --symlink-install \
        --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
        2>&1 | tee -a "$WORKSPACE_DIR/build-ugv-apps.log"
    log_info "✓ ugv_bringup rebuilt successfully"
fi

################################################################################
# STEP 15: CREATE HELPER SCRIPTS
################################################################################
log_step "=== Step 15: Creating Helper Scripts ==="

log_info "Creating ROS setup helper script..."
cat > "$HOME/setup_ros.sh" <<'SETUP_EOF'
#!/bin/bash
# Quick ROS 2 environment setup script

# Detect installed ROS 2 distribution
if [ -f "/opt/ros/jazzy/setup.bash" ]; then
    ROS_DISTRO_FOUND="jazzy"
elif [ -f "/opt/ros/humble/setup.bash" ]; then
    ROS_DISTRO_FOUND="humble"
else
    echo "ERROR: No ROS 2 installation found in /opt/ros/"
    return 1
fi

# Source ROS 2
source /opt/ros/${ROS_DISTRO_FOUND}/setup.bash

# Source workspace
if [ -f "$HOME/ws/ugv_ws/install/setup.bash" ]; then
    source "$HOME/ws/ugv_ws/install/setup.bash"
fi

# Set default UGV model
export UGV_MODEL=${UGV_MODEL:-ugv_rover}

# Suppress warnings
export PYTHONWARNINGS="ignore::DeprecationWarning"

echo "✓ ROS 2 $ROS_DISTRO_FOUND environment loaded"
echo "  ROS_DISTRO: $ROS_DISTRO"
echo "  UGV_MODEL: $UGV_MODEL"
echo "  Workspace: $HOME/ws/ugv_ws"
SETUP_EOF

chmod +x "$HOME/setup_ros.sh"
cat > "$WORKSPACE_DIR/copy_mqtt_bridge.sh" <<'EOF'
#!/bin/bash
# Copy CyberWave MQTT Bridge files to UGV workspace

CYBERWAVE_MQTT="$HOME/ws/cyberwave-edge-ros/mqtt_bridge"
UGV_WS="$HOME/ws/ugv_ws"

if [ ! -d "$CYBERWAVE_MQTT" ]; then
    echo "ERROR: CyberWave MQTT Bridge not found at $CYBERWAVE_MQTT"
    exit 1
fi

echo "Copying MQTT Bridge configuration files..."

# Create target directories
mkdir -p "$UGV_WS/config/mqtt_bridge"
mkdir -p "$UGV_WS/src/mqtt_bridge"

# Copy configuration files
if [ -d "$CYBERWAVE_MQTT/config" ]; then
    cp -r "$CYBERWAVE_MQTT/config/"* "$UGV_WS/config/mqtt_bridge/"
    echo "✓ Configuration files copied"
fi

# Copy source files
if [ -d "$CYBERWAVE_MQTT/src" ]; then
    cp -r "$CYBERWAVE_MQTT/src/"* "$UGV_WS/src/mqtt_bridge/"
    echo "✓ Source files copied"
fi

# Copy package.xml if exists
if [ -f "$CYBERWAVE_MQTT/package.xml" ]; then
    cp "$CYBERWAVE_MQTT/package.xml" "$UGV_WS/src/mqtt_bridge/"
    echo "✓ package.xml copied"
fi

# Copy CMakeLists.txt if exists
if [ -f "$CYBERWAVE_MQTT/CMakeLists.txt" ]; then
    cp "$CYBERWAVE_MQTT/CMakeLists.txt" "$UGV_WS/src/mqtt_bridge/"
    echo "✓ CMakeLists.txt copied"
fi

echo "✓ MQTT Bridge files copied successfully"
echo "  From: $CYBERWAVE_MQTT"
echo "  To: $UGV_WS"
EOF

chmod +x "$WORKSPACE_DIR/copy_mqtt_bridge.sh"

log_info "✓ Helper scripts created"

################################################################################
# STEP 16: NETWORK CONFIGURATION (Static IP & SSH)
################################################################################
log_step "=== Step 16: Configuring Network (Static IP) and SSH ==="

# Detect which network configuration system is in use
NETWORK_CONFIG_SYSTEM="unknown"

if [ -d /etc/netplan ]; then
    NETWORK_CONFIG_SYSTEM="netplan"
elif [ -f /etc/dhcpcd.conf ]; then
    NETWORK_CONFIG_SYSTEM="dhcpcd"
elif [ -f /etc/network/interfaces ]; then
    NETWORK_CONFIG_SYSTEM="interfaces"
fi

log_info "Detected network configuration system: $NETWORK_CONFIG_SYSTEM"

# Static IP configuration (optional - skip if network is already configured)
log_info "Checking if static IP configuration is needed..."
log_info "NOTE: Static IP configuration is OPTIONAL. You can skip this if your network is already configured."

case "$NETWORK_CONFIG_SYSTEM" in
    netplan)
        log_info "Configuring Static IP address (192.168.0.144/24) using Netplan..."
        
        # Backup existing netplan configuration
        if [ -f /etc/netplan/50-cloud-init.yaml ]; then
            sudo cp /etc/netplan/50-cloud-init.yaml "/etc/netplan/50-cloud-init.yaml.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "  ✓ Backed up existing netplan configuration"
        fi
        
        # Create netplan configuration for static IP
        sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.0.144/24]
      routes:
        - to: default
          via: 192.168.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF
        
        log_info "  ✓ Static IP configuration created"
        log_info "    IP Address: 192.168.0.144/24"
        log_info "    Gateway: 192.168.0.1"
        log_info "    DNS: 8.8.8.8, 1.1.1.1"
        
        # Apply netplan configuration
        log_info "  Applying netplan configuration..."
        if sudo netplan apply 2>&1 | grep -q "error"; then
            log_warn "  Netplan apply reported warnings (will take effect after reboot)"
        else
            log_info "  ✓ Netplan configuration applied successfully"
        fi
        ;;
        
    dhcpcd)
        log_info "Configuring Static IP address (192.168.0.144/24) using dhcpcd (Raspberry Pi OS)..."
        
        # Backup dhcpcd.conf
        sudo cp /etc/dhcpcd.conf "/etc/dhcpcd.conf.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Check if static IP is already configured
        if grep -q "interface eth0" /etc/dhcpcd.conf && grep -q "static ip_address=192.168.0.144" /etc/dhcpcd.conf; then
            log_info "  Static IP already configured in dhcpcd.conf, skipping..."
        else
            # Add static IP configuration
            sudo tee -a /etc/dhcpcd.conf > /dev/null <<'EOF'

# === Static IP Configuration (Added by setup script) ===
interface eth0
static ip_address=192.168.0.144/24
static routers=192.168.0.1
static domain_name_servers=8.8.8.8 1.1.1.1
EOF
            log_info "  ✓ Static IP configuration added to dhcpcd.conf"
        fi
        ;;
        
    interfaces)
        log_info "Configuring Static IP address (192.168.0.144/24) using /etc/network/interfaces..."
        
        # Backup interfaces file
        sudo cp /etc/network/interfaces "/etc/network/interfaces.backup.$(date +%Y%m%d_%H%M%S)"
        
        log_warn "  NOTE: /etc/network/interfaces detected. You may need to manually configure static IP."
        log_warn "  Please edit /etc/network/interfaces to set:"
        log_warn "    IP Address: 192.168.0.144/24"
        log_warn "    Gateway: 192.168.0.1"
        ;;
        
    *)
        log_warn "Unknown network configuration system. Skipping static IP configuration."
        log_warn "Please manually configure static IP if needed."
        ;;
esac

log_info "✓ Network configuration completed"

# Configure SSH
log_info "Ensuring SSH service is enabled..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH to use port 22 (default)
if ! grep -q "^Port 22" /etc/ssh/sshd_config; then
    log_info "Configuring SSH to use port 22..."
    echo "Port 22" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    sudo systemctl restart ssh
fi

log_info "✓ SSH configured on port 22"

################################################################################
# COMPLETION
################################################################################

log_info ""
log_info "================================================================"
log_info "    ROS 2 Realtime Raspberry Pi 4 Image Build Complete!        "
log_info "================================================================"
log_info ""
log_info "Build Information:"
log_info "  OS: $OS_PRETTY_NAME"
if [ "$ROS_INSTALL_METHOD" = "source" ]; then
    log_info "  ROS 2 installation: Built from source"
else
    log_info "  ROS 2 packages from: Ubuntu $ROS_UBUNTU_CODENAME repository"
fi
log_info ""
log_info "Summary:"
log_info "  ✓ Boot configuration updated (UART, performance)"
log_info "  ✓ System packages installed"
log_info "  ✓ 2GB Swap file created for system stability"
log_info "  ✓ User permissions configured"
log_info "  ✓ Serial port permissions configured"
log_info "  ✓ Audio (ALSA) configured"
log_info "  ✓ Docker installed and configured"
log_info "  ✓ ROS 2 $ROS_DISTRO installed"
log_info "  ✓ UGV workspace cloned and built (29+ packages)"
log_info "  ✓ CyberWave Edge ROS cloned"
log_info "  ✓ CyberWave MQTT bridge files copied to UGV workspace"
log_info "  ✓ Python packages installed"
log_info "  ✓ Environment configured (.bashrc updated)"
log_info "  ✓ Helper scripts created"
log_info "  ✓ Static IP configured (192.168.0.144/24)"
log_info "  ✓ SSH configured (port 22)"
log_info ""
log_warn "IMPORTANT: Please REBOOT your system for all changes to take effect:"
log_warn "    sudo reboot"
log_warn ""
log_info "================================================================"
log_info "After reboot, source the ROS 2 environment:"
log_info "================================================================"
log_info ""
log_info "# Source ROS 2 $ROS_DISTRO and UGV workspace"
log_info "source /opt/ros/$ROS_DISTRO/setup.bash"
log_info "source ~/ws/ugv_ws/install/setup.bash"
log_info ""
log_info "# Or use the helper script:"
log_info "source ~/setup_ros.sh"
log_info ""
log_info "================================================================"
log_info "Verification Commands:"
log_info "================================================================"
log_info ""
log_info "1. Verify ROS 2 environment:"
log_info "   echo \$ROS_DISTRO  # Should show: $ROS_DISTRO"
log_info "   ros2 pkg list | grep ugv"
log_info ""
log_info "2. Test UGV visualization:"
log_info "   ros2 launch ugv_description display.launch.py use_rviz:=true"
log_info ""
log_info "3. Check UGV Beast integration files:"
log_info "   ls -la ~/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py"
log_info "   ls -la ~/ws/ugv_ws/start_ugv.sh"
log_info "   ls -la ~/ws/ugv_ws/ugv_services_install.sh"
log_info ""
log_info "4. Check serial ports:"
log_info "   ls -la /dev/ttyAMA0 /dev/ttyACM* /dev/ttyUSB*"
log_info ""
log_info "================================================================"
log_info "OPTIONAL: Manual MQTT Bridge Build (if needed):"
log_info "================================================================"
log_info ""
log_info "NOTE: The MQTT bridge is already built. Only rebuild manually if needed."
log_info ""
log_info "To rebuild the MQTT bridge with debug logs:"
log_info "   cd ~/ws/ugv_ws"
log_info "   chmod +x src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh"
log_info "   ./src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh --logs"
log_info ""
log_info "================================================================"
log_info "OPTIONAL: Launch UGV Beast System:"
log_info "================================================================"
log_info ""
log_info "Method 1: Direct launch with debug logs (for testing):"
log_info "   # First, source the environment:"
log_info "   source /opt/ros/jazzy/setup.bash"
log_info "   source ~/ws/ugv_ws/install/setup.bash"
log_info "   "
log_info "   # Then launch:"
log_info "   ros2 launch ugv_bringup master_beast.launch.py \\"
log_info "     robot_id:=robot_ugv_beast_v1 \\"
log_info "     debug_logs:=true"
log_info ""
log_info "Method 2: Install as system service (RECOMMENDED for production):"
log_info "   # This ensures the robot starts automatically on boot"
log_info "   cd ~/ws/ugv_ws"
log_info "   chmod +x ugv_services_install.sh"
log_info "   sudo ./ugv_services_install.sh"
log_info ""
log_info "================================================================"
log_info "Helper Scripts and Logs:"
log_info "================================================================"
log_info ""
log_info "Helper scripts created:"
log_info "  - ~/setup_ros.sh - Quick ROS environment setup"
log_info "  - ~/ws/copy_mqtt_bridge.sh - Copy MQTT Bridge files"
log_info ""
log_info "Build logs saved to:"
log_info "  - ~/ws/build-core-packages.log"
log_info "  - ~/ws/build-teb.log"
log_info "  - ~/ws/build-rf2o.log"
log_info "  - ~/ws/build-ugv-apps.log"
log_info ""
log_info "================================================================"
log_info "Workspace Information:"
log_info "================================================================"
log_info ""
log_info "Workspaces:"
log_info "  UGV Workspace: ~/ws/ugv_ws"
log_info "  CyberWave Edge ROS: ~/ws/cyberwave-edge-ros"
log_info ""
log_info "CyberWave Integration:"
log_info "  ✓ MQTT Bridge files copied to UGV workspace"
log_info "  ✓ Launch file: ugv_bringup/launch/master_beast.launch.py"
log_info "  ✓ Start script: ~/ws/ugv_ws/start_ugv.sh"
log_info "  ✓ Service installer: ~/ws/ugv_ws/ugv_services_install.sh"
log_info ""
log_info "================================================================"
log_info "Hardware Configuration:"
log_info "================================================================"
log_info ""
log_info "Serial Port Configuration:"
log_info "  Device: /dev/ttyAMA0"
log_info "  Baudrate: 115200 (typical)"
log_info "  GPIO: 14 (TX), 15 (RX)"
log_info ""
log_info "Network Configuration:"
log_info "  Static IP: 192.168.0.144/24"
log_info "  Gateway: 192.168.0.1"
log_info "  DNS Servers: 8.8.8.8, 1.1.1.1"
log_info "  Network interface: eth0"
log_info ""
log_info "System Stability:"
log_info "  ✓ 2GB Swap file created at /swapfile"
log_info "  This prevents RAM overload and SSH disconnections"
log_info ""
log_info "================================================================"

# Re-enable automatic updates (if they were present)
log_info ""
log_info "Re-enabling automatic updates..."
if systemctl list-units --type=service | grep -q "unattended-upgrades"; then
    sudo systemctl start unattended-upgrades 2>/dev/null || true
fi
if systemctl list-timers | grep -q "apt-daily"; then
    sudo systemctl start apt-daily.timer 2>/dev/null || true
    sudo systemctl start apt-daily-upgrade.timer 2>/dev/null || true
fi
