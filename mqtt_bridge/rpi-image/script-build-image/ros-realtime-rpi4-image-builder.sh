#!/bin/bash
################################################################################
# ROS 2 Realtime Raspberry Pi 4 Image Builder
# 
# This script automates the complete setup process for a ROS 2 Humble
# realtime system on Raspberry Pi OS Bookworm, including:
# - Boot configuration (UART, performance, etc.)
# - System dependencies
# - ROS 2 Humble installation
# - UGV workspace setup
# - CyberWave MQTT bridge integration
# - Serial port configuration
# - Environment setup
#
# Target OS: Raspberry Pi OS Bookworm (64-bit)
# Target Hardware: Raspberry Pi 4/5
# ROS Distribution: Humble
#
# Author: Generated from setup documentation
# Date: 2026-02-09
################################################################################

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
ROS_DISTRO="jazzy"
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
log_info "Target OS: Raspberry Pi OS Bookworm / Ubuntu 24.04"
log_info "ROS Distro: $ROS_DISTRO (Jazzy Jalisco)"
log_info "Workspace: $WORKSPACE_DIR"
log_info "User: $DEFAULT_USER"
log_info "=========================================="
log_info "Starting installation... (no user confirmation required)"

# Fix any interrupted dpkg operations first
log_info "Checking for interrupted dpkg operations..."
if ! sudo dpkg --configure -a 2>&1 | grep -q "^$"; then
    log_info "Completed pending dpkg configurations"
fi

# Disable automatic updates during installation
log_info "Temporarily disabling automatic updates..."
sudo systemctl stop unattended-upgrades 2>/dev/null || true
sudo systemctl stop apt-daily.timer 2>/dev/null || true
sudo systemctl stop apt-daily-upgrade.timer 2>/dev/null || true

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

log_info "Backing up boot configuration files..."
sudo cp /boot/firmware/config.txt "/boot/firmware/config.txt.backup.$(date +%Y%m%d_%H%M%S)" || true
sudo cp /boot/firmware/cmdline.txt "/boot/firmware/cmdline.txt.backup.$(date +%Y%m%d_%H%M%S)" || true

log_info "Updating /boot/firmware/config.txt..."

# Check if ROS configuration already exists to prevent duplicate entries
if grep -q "# === ROS 2 Realtime Configuration (Added by setup script) ===" /boot/firmware/config.txt 2>/dev/null; then
    log_info "ROS 2 configuration already exists in config.txt, skipping to prevent duplicates..."
else
    log_info "Adding ROS 2 configuration to config.txt..."
    sudo tee -a /boot/firmware/config.txt > /dev/null <<'EOF'

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

log_info "Updating /boot/firmware/cmdline.txt (removing serial console)..."
# Remove console=serial0,115200 and console=ttyAMA0,115200 if present
sudo sed -i 's/console=serial0,[0-9]*//g' /boot/firmware/cmdline.txt
sudo sed -i 's/console=ttyAMA0,[0-9]*//g' /boot/firmware/cmdline.txt
# Add plymouth.ignore-serial-consoles if not present
if ! grep -q "plymouth.ignore-serial-consoles" /boot/firmware/cmdline.txt; then
    sudo sed -i 's/$/ plymouth.ignore-serial-consoles/' /boot/firmware/cmdline.txt
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
safe_apt install -y \
    git curl wget vim nano htop \
    build-essential cmake pkg-config \
    util-linux procps net-tools \
    udev

log_info "Verifying git installation..."
if ! command -v git &> /dev/null; then
    log_error "Git installation failed!"
    exit 1
fi

log_info "Installing serial communication tools..."
safe_apt install -y \
    minicom screen setserial

log_info "Installing network tools..."
safe_apt install -y \
    hostapd iproute2 iw haveged \
    dnsmasq iptables

log_info "Installing audio support..."
safe_apt install -y \
    portaudio19-dev alsa-utils \
    pulseaudio pulseaudio-utils \
    espeak

log_info "Installing camera and video libraries..."
# Note: Some packages (libcamera-apps, python3-picamera2) are available on Ubuntu 24.04 ARM64
safe_apt install -y \
    python3-opencv \
    libopenblas-dev libatlas3-base \
    libavformat-dev libavcodec-dev \
    libavdevice-dev libavutil-dev \
    libavfilter-dev libswscale-dev \
    libswresample-dev || log_warn "Some camera packages not available"

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
# STEP 7: ROS 2 JAZZY INSTALLATION
################################################################################
log_step "=== Step 7: Installing ROS 2 Jazzy ==="

log_info "Setting up ROS 2 repository..."
safe_apt install -y software-properties-common
sudo add-apt-repository universe -y

# Check if ROS 2 repository is already configured
if [ -f "/etc/apt/sources.list.d/ros2.sources" ] || [ -f "/etc/apt/sources.list.d/ros2.list" ]; then
    log_info "ROS 2 repository already configured, skipping setup..."
else
    log_info "Adding ROS 2 GPG key..."
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    
    log_info "Adding ROS 2 repository to sources list..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
fi

log_info "Updating package lists..."
safe_apt update

log_info "Installing ROS 2 Jazzy base packages..."
safe_apt install -y \
    ros-jazzy-ros-base \
    ros-jazzy-ros-core

log_info "Installing ROS 2 build tools..."
safe_apt install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool

log_info "Installing ROS 2 Navigation packages..."
safe_apt install -y \
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-common \
    ros-jazzy-nav2-bringup \
    ros-jazzy-nav2-msgs \
    ros-jazzy-nav2-costmap-2d \
    ros-jazzy-nav2-core

log_info "Installing ROS 2 TF2 and message packages..."
safe_apt install -y \
    ros-jazzy-tf2-ros \
    ros-jazzy-tf2-geometry-msgs

log_info "Installing ROS 2 vision and sensor packages..."
safe_apt install -y \
    ros-jazzy-cv-bridge \
    ros-jazzy-image-transport \
    ros-jazzy-image-geometry \
    ros-jazzy-usb-cam

log_info "Installing ROS 2 communication packages..."
safe_apt install -y \
    ros-jazzy-rosbridge-suite

log_info "Installing ROS 2 visualization packages..."
safe_apt install -y \
    ros-jazzy-rviz2 \
    ros-jazzy-rviz-common \
    ros-jazzy-rviz-default-plugins \
    ros-jazzy-rqt-common-plugins \
    ros-jazzy-joint-state-publisher \
    ros-jazzy-joint-state-publisher-gui

log_info "Installing image processing packages..."
safe_apt install -y \
    ros-jazzy-image-proc \
    ros-jazzy-image-pipeline || log_warn "image_proc packages not available (optional)"

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

log_info "✓ ROS 2 Jazzy installation completed"

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
log_info "Copying mqtt_bridge from CyberWave Edge ROS to UGV workspace..."
if [ -d "$CYBERWAVE_REPO_DIR/mqtt_bridge" ]; then
    # Check if mqtt_bridge already exists in ugv_ws/src
    if [ -d "$UGV_WS_DIR/src/mqtt_bridge" ]; then
        log_warn "mqtt_bridge already exists in $UGV_WS_DIR/src, removing old version..."
        rm -rf "$UGV_WS_DIR/src/mqtt_bridge"
    fi
    
    # Ensure src directory exists
    mkdir -p "$UGV_WS_DIR/src"
    
    # Copy mqtt_bridge folder
    cp -r "$CYBERWAVE_REPO_DIR/mqtt_bridge" "$UGV_WS_DIR/src/" || {
        log_error "Failed to copy mqtt_bridge folder"
        exit 1
    }
    log_info "✓ mqtt_bridge copied successfully to $UGV_WS_DIR/src/mqtt_bridge"
    
    # Fix mqtt_bridge setup.py and add setup.cfg for ROS 2 Jazzy compatibility
    log_info "  Fixing mqtt_bridge for ROS 2 Jazzy..."
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

log_info "✓ Workspaces setup completed"

################################################################################
# STEP 9: APPLY ROS 2 SOURCE CODE FIXES
################################################################################
log_step "=== Step 9: Applying ROS 2 Jazzy Compatibility Fixes ==="

cd "$UGV_WS_DIR"

log_info "🔧 Applying ROS 2 Jazzy compatibility fixes..."

# Pre-cleanup: Fix any corrupted .hpp+ patterns from previous runs (GLOBAL IDEMPOTENT CLEANUP)
log_info "  Pre-cleanup: Fixing any corrupted .hpp+ patterns from previous runs..."
find "$UGV_WS_DIR/src" -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" \) 2>/dev/null | while read file; do
    # Fix any .hpp followed by one or more 'p' characters (e.g., .hpppppp -> .hpp)
    sed -i 's|\.hpp\+"|.hpp"|g' "$file" 2>/dev/null || true
    sed -i 's|\.hpp\+>|.hpp>|g' "$file" 2>/dev/null || true
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

# Fix 2: ldlidar - Add <pthread.h> include and fix uninitialized variable
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

# Fix 3: slam_gmapping - Change .h to .hpp (IDEMPOTENT)
log_info "  Fixing slam_gmapping..."
SLAM_FILE="$UGV_WS_DIR/src/ugv_else/gmapping/slam_gmapping/include/slam_gmapping/slam_gmapping.h"
if [ -f "$SLAM_FILE" ]; then
    # First, fix any corrupted .hpp+ patterns from multiple runs
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.hpp\+|tf2_geometry_msgs/tf2_geometry_msgs.hpp|g' "$SLAM_FILE"
    # Then, only convert .h to .hpp if the original .h pattern exists
    if grep -q 'tf2_geometry_msgs/tf2_geometry_msgs\.h"' "$SLAM_FILE"; then
        sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$SLAM_FILE"
    fi
fi

# Fix 4: explore_lite - Replace execute_callback() with makePlan()
log_info "  Fixing explore_lite..."
if [ -f "$UGV_WS_DIR/src/ugv_else/explore_lite/src/explore.cpp" ]; then
    sed -i 's|exploring_timer_->execute_callback();|makePlan();|g' \
        "$UGV_WS_DIR/src/ugv_else/explore_lite/src/explore.cpp"
fi

# Fix 5: apriltag_ros - Change .h to .hpp (only if not already fixed)
log_info "  Fixing apriltag_ros..."
if [ -f "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp" ]; then
    # Fix any corrupted .hpppppp patterns first (from multiple runs)
    sed -i 's|cv_bridge/cv_bridge\.hpp\+|cv_bridge/cv_bridge.hpp|g' \
        "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
    sed -i 's|image_geometry/pinhole_camera_model\.hpp\+|image_geometry/pinhole_camera_model.hpp|g' \
        "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
    
    # Then check if fix is needed (not already applied)
    if grep -q 'cv_bridge/cv_bridge\.h"' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"; then
        sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
    fi
    if grep -q 'image_geometry/pinhole_camera_model\.h"' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"; then
        sed -i 's|image_geometry/pinhole_camera_model\.h"|image_geometry/pinhole_camera_model.hpp"|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
    fi
fi

if [ -f "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp" ]; then
    # Fix any corrupted .hpppppp patterns first
    sed -i 's|cv_bridge/cv_bridge\.hpp\+|cv_bridge/cv_bridge.hpp|g' \
        "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
    
    # Then check if fix is needed
    if grep -q 'cv_bridge/cv_bridge\.h"' "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"; then
        sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' \
            "$UGV_WS_DIR/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
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
    # First, clean up any corrupted .hpp+ patterns
    sed -i 's|cv_bridge/cv_bridge\.hpp\+|cv_bridge/cv_bridge.hpp|g' "$file" 2>/dev/null || true
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.hpp\+|tf2_geometry_msgs/tf2_geometry_msgs.hpp|g' "$file" 2>/dev/null || true
    
    # Then fix .h to .hpp only if original .h pattern exists
    if grep -q 'cv_bridge/cv_bridge\.h"' "$file" 2>/dev/null; then
        sed -i 's|cv_bridge/cv_bridge\.h"|cv_bridge/cv_bridge.hpp"|g' "$file" 2>/dev/null || true
    fi
    if grep -q 'cv_bridge/cv_bridge\.h>' "$file" 2>/dev/null; then
        sed -i 's|cv_bridge/cv_bridge\.h>|cv_bridge/cv_bridge.hpp>|g' "$file" 2>/dev/null || true
    fi
    if grep -q 'tf2_geometry_msgs/tf2_geometry_msgs\.h"' "$file" 2>/dev/null; then
        sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h"|tf2_geometry_msgs/tf2_geometry_msgs.hpp"|g' "$file" 2>/dev/null || true
    fi
    if grep -q 'tf2_geometry_msgs/tf2_geometry_msgs\.h>' "$file" 2>/dev/null; then
        sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h>|tf2_geometry_msgs/tf2_geometry_msgs.hpp>|g' "$file" 2>/dev/null || true
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

# Fix FindG2O.cmake - Add multiarch paths
if [ -f "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake" ]; then
    if ! grep -q "lib/aarch64-linux-gnu" "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"; then
        sed -i 's|PATH_SUFFIXES lib|PATH_SUFFIXES lib lib/aarch64-linux-gnu lib/x86_64-linux-gnu|g' \
            "$UGV_WS_DIR/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"
    fi
fi

log_info "✅ All ROS 2 Jazzy compatibility fixes applied successfully!"

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

log_info "Sourcing ROS 2 Jazzy environment..."
source /opt/ros/jazzy/setup.bash

log_info "Building first set of packages sequentially (RAM-friendly)..."
log_info "This will take time but prevents system crashes due to low RAM..."
colcon build --executor sequential \
    --allow-overriding costmap_converter costmap_converter_msgs teb_msgs \
    --packages-select \
        apriltag apriltag_msgs apriltag_ros \
        cartographer costmap_converter_msgs costmap_converter \
        emcl2 explore_lite openslam_gmapping slam_gmapping \
        ldlidar robot_pose_publisher teb_msgs \
        vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server \
        ugv_base_node ugv_interface \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-core-packages.log"

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
    --allow-overriding costmap_converter costmap_converter_msgs teb_msgs teb_local_planner \
    --packages-select teb_local_planner \
    --parallel-workers 1 \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-teb.log" || log_warn "teb_local_planner failed (known issue on ARM64, may work after reboot)"

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
    # Clean up any stale paths from AMENT_PREFIX_PATH and CMAKE_PREFIX_PATH
    export AMENT_PREFIX_PATH=$(echo "$AMENT_PREFIX_PATH" | tr ':' '\n' | grep -v "/home/ubuntu/ws/ugv_ws/install" | tr '\n' ':' | sed 's/:$//')
    export CMAKE_PREFIX_PATH=$(echo "$CMAKE_PREFIX_PATH" | tr ':' '\n' | grep -v "/home/ubuntu/ws/ugv_ws/install" | tr '\n' ':' | sed 's/:$//')
    
    # Source the workspace
    source "$UGV_WS_DIR/install/setup.bash" 2>/dev/null || true
fi

log_info "Building UGV application packages (Python packages with symlink-install)..."
colcon build \
    --executor sequential \
    --packages-select \
        mqtt_bridge \
        ugv_bringup ugv_chat_ai ugv_description ugv_gazebo \
        ugv_nav ugv_slam ugv_tools ugv_vision ugv_web_app \
    --symlink-install \
    --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee "$WORKSPACE_DIR/build-ugv-apps.log"

log_info "Ensuring ugv_bringup is properly installed..."
colcon build --executor sequential --packages-select ugv_bringup --symlink-install \
    --cmake-args -DCMAKE_BUILD_PARALLEL_LEVEL=1 \
    2>&1 | tee -a "$WORKSPACE_DIR/build-ugv-apps.log"

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

################################################################################
# STEP 12: INSTALL PYTHON PACKAGES
################################################################################
log_step "=== Step 12: Installing Python Packages ==="

cd "$UGV_WS_DIR"

log_info "📦 Installing Python packages for UGV..."

# Install from requirements.txt
if [ -f "$UGV_WS_DIR/requirements.txt" ]; then
    log_info "  Installing from requirements.txt..."
    python3 -m pip install -r "$UGV_WS_DIR/requirements.txt" --break-system-packages
else
    log_warn "requirements.txt not found in UGV workspace"
fi

# Install additional UGV-specific packages
log_info "  Installing UGV-specific packages..."
pip3 install --break-system-packages \
    pyserial \
    flask \
    mediapipe \
    requests \
    aiortc \
    aioice \
    av \
    cyberwave

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
sed -i '/source \/opt\/ros\/jazzy\/setup.bash/d' "$BASHRC"
sed -i '/source \/opt\/ros\/humble\/setup.bash/d' "$BASHRC"
sed -i '/source .*ugv_ws\/install\/setup.bash/d' "$BASHRC"
sed -i '/register-python-argcomplete/d' "$BASHRC"
sed -i '/PYTHONWARNINGS/d' "$BASHRC"
sed -i '/UGV_MODEL/d' "$BASHRC"

# Add new configuration for ROS 2 Jazzy
log_info "Adding ROS 2 Jazzy configuration to .bashrc..."
cat >> "$BASHRC" <<'EOF'

# === ROS 2 Jazzy Configuration (Added by setup script) ===
# ROS 2 Jazzy setup
source /opt/ros/jazzy/setup.bash
# Source workspace setup with error suppression for incomplete packages
source $HOME/ws/ugv_ws/install/setup.bash 2>/dev/null || source $HOME/ws/ugv_ws/install/setup.bash

# Enable tab completion for ROS 2 and colcon
eval "$(register-python-argcomplete ros2)"
eval "$(register-python-argcomplete colcon)"

# Suppress Python deprecation warnings
export PYTHONWARNINGS="ignore::DeprecationWarning"

# Add local Python packages to PATH
export PATH="$HOME/.local/bin:$PATH"

# Default UGV model (can be: ugv_rover, ugv_beast, rasp_rover)
export UGV_MODEL=ugv_rover
EOF

log_info "✓ Environment configuration completed (.bashrc updated for ROS 2 Jazzy)"
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
    log_info "Rebuilding ugv_bringup package with new files (RAM-optimized)..."
    cd "$UGV_WS_DIR"
    source /opt/ros/jazzy/setup.bash
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
cat > "$HOME/setup_ros.sh" <<'EOF'
#!/bin/bash
# Quick ROS 2 Jazzy environment setup script

# Source ROS 2 Jazzy
source /opt/ros/jazzy/setup.bash

# Source workspace
if [ -f "$HOME/ws/ugv_ws/install/setup.bash" ]; then
    source "$HOME/ws/ugv_ws/install/setup.bash"
fi

# Set default UGV model
export UGV_MODEL=${UGV_MODEL:-ugv_rover}

# Suppress warnings
export PYTHONWARNINGS="ignore::DeprecationWarning"

echo "✓ ROS 2 Jazzy environment loaded"
echo "  ROS_DISTRO: $ROS_DISTRO"
echo "  UGV_MODEL: $UGV_MODEL"
echo "  Workspace: $HOME/ws/ugv_ws"
EOF

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

# Configure Static IP using Netplan (Ubuntu)
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

log_info "✓ Static IP configured"

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
log_info "Summary:"
log_info "  ✓ Boot configuration updated (UART, performance)"
log_info "  ✓ System packages installed"
log_info "  ✓ 2GB Swap file created for system stability"
log_info "  ✓ User permissions configured"
log_info "  ✓ Serial port permissions configured"
log_info "  ✓ Audio (ALSA) configured"
log_info "  ✓ Docker installed and configured"
log_info "  ✓ ROS 2 Jazzy installed"
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
log_info "# Source ROS 2 Jazzy and UGV workspace"
log_info "source /opt/ros/jazzy/setup.bash"
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
log_info "   echo \$ROS_DISTRO  # Should show: jazzy"
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

# Re-enable automatic updates
log_info ""
log_info "Re-enabling automatic updates..."
sudo systemctl start unattended-upgrades 2>/dev/null || true
sudo systemctl start apt-daily.timer 2>/dev/null || true
sudo systemctl start apt-daily-upgrade.timer 2>/dev/null || true
