#!/bin/bash
################################################################################
# Cyberwave UGV Beast Complete Image Builder
# 
# Creates a Raspberry Pi 5 image with COMPLETE ROS 2 Jazzy environment
# pre-installed - NO compilation needed after flashing!
#
# This script copies:
#   - Pre-built ROS 2 Jazzy installation (/opt/ros/jazzy)
#   - Pre-built UGV workspace (/home/USER/ws/ugv_ws)
#   - CyberWave Edge ROS repository
#   - All system configurations (udev, docker, audio, network, etc.)
#   - User environment (.bashrc, helper scripts)
#   - Python packages (from .local)
#   - All configurations from cyb-ugv-builder.sh
#
# Base Image: Raspberry Pi OS Lite (Debian Bookworm/12) ARM64
# (Same as the current host system)
#
# Requirements:
#   - Linux host with root privileges
#   - Pre-built ROS 2 Jazzy on host (from cyb-ugv-builder.sh)
#   - ~20GB free disk space
#   - Tools: wget, xz, kpartx, parted, rsync
#
# Usage:
#   sudo ./create_ugv_image.sh
#
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $1"; }

# Root check
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the actual user who ran sudo
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# CONFIGURATION - Edit these paths as needed
################################################################################

# Source paths on the host (your pre-built ROS environment)
HOST_ROS2_INSTALL="/opt/ros/jazzy"
HOST_ROS2_SRC="/opt/ros/jazzy_src"           # Optional: ROS2 source (for debugging)
HOST_USER_WS="${ACTUAL_HOME}/ws"             # User workspace directory (entire /ws folder)
HOST_UGV_WS="${HOST_USER_WS}/ugv_ws"         # UGV workspace
HOST_CYBERWAVE="${HOST_USER_WS}/cyberwave-edge-ros"  # CyberWave repo
HOST_LOCAL="${ACTUAL_HOME}/.local"           # Python packages
HOST_BASHRC="${ACTUAL_HOME}/.bashrc"         # User bashrc

# Destination paths inside the Pi image
PI_USER="pi"                                  # Target username in image
PI_HOME="/home/${PI_USER}"
PI_ROS2_INSTALL="/opt/ros/jazzy"
PI_ROS2_SRC="/opt/ros/jazzy_src"
PI_USER_WS="${PI_HOME}/ws"
PI_UGV_WS="${PI_USER_WS}/ugv_ws"
PI_CYBERWAVE="${PI_USER_WS}/cyberwave-edge-ros"

# Working directories
WORK_DIR="${SCRIPT_DIR}/build_img"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MOUNT_DIR="${WORK_DIR}/mnt"

# Base image - Raspberry Pi OS Lite 64-bit (Debian Bookworm based)
# SAME VERSION as the current host system (Debian 12 Bookworm)
# Official Raspberry Pi OS - supports Pi 5 natively
BASE_IMAGE_URL="https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"
BASE_IMAGE_NAME="raspios-bookworm-arm64-lite.img"
OUTPUT_IMAGE_NAME="CYB_UGV_Beast_ROS2_Jazzy_Bookworm_$(date +%Y%m%d).img"

# Additional space to add (in GB) - ROS2 + workspace needs more space
EXTRA_SPACE_GB=10

# Include ROS2 source code? (adds ~3GB but useful for debugging)
INCLUDE_ROS2_SRC=false

# Include entire /ws folder (not just ugv_ws)?
INCLUDE_FULL_WS=true

################################################################################
# Pre-Flight Checks
################################################################################

log_info "========================================"
log_info "Cyberwave UGV Beast Complete Image Builder"
log_info "Raspberry Pi OS (Debian Bookworm) + ROS 2 Jazzy"
log_info "========================================"
echo ""
log_info "Source User: $ACTUAL_USER"
log_info "Source Home: $ACTUAL_HOME"
echo ""

# Check ROS 2 installation exists
if [ ! -d "$HOST_ROS2_INSTALL" ]; then
    log_error "ROS 2 Jazzy installation not found: $HOST_ROS2_INSTALL"
    log_info "Please run cyb-ugv-builder.sh first to build ROS 2."
    exit 1
fi

if [ ! -f "$HOST_ROS2_INSTALL/setup.bash" ]; then
    log_error "ROS 2 setup.bash not found: $HOST_ROS2_INSTALL/setup.bash"
    exit 1
fi

# Check UGV workspace exists
if [ ! -d "$HOST_UGV_WS" ]; then
    log_error "UGV workspace not found: $HOST_UGV_WS"
    log_info "Please run cyb-ugv-builder.sh first to build the workspace."
    exit 1
fi

if [ ! -f "$HOST_UGV_WS/install/setup.bash" ]; then
    log_error "UGV workspace not built: $HOST_UGV_WS/install/setup.bash not found"
    exit 1
fi

# Check for required tools
log_info "Checking required tools..."
REQUIRED_TOOLS="wget xz kpartx losetup parted rsync e2fsck resize2fs"
MISSING_TOOLS=""

for tool in $REQUIRED_TOOLS; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    log_error "Missing tools:$MISSING_TOOLS"
    log_info "Install with: sudo apt-get install -y wget xz-utils kpartx parted rsync e2fsprogs"
    exit 1
fi

log_success "All tools available"

# Calculate total size needed
log_info "Calculating space requirements..."
ROS2_SIZE=$(du -sm "$HOST_ROS2_INSTALL" 2>/dev/null | cut -f1)
WS_SIZE=$(du -sm "$HOST_USER_WS" 2>/dev/null | cut -f1)
LOCAL_SIZE=$(du -sm "$HOST_LOCAL" 2>/dev/null | cut -f1 || echo "0")

if [ "$INCLUDE_ROS2_SRC" = true ] && [ -d "$HOST_ROS2_SRC" ]; then
    ROS2_SRC_SIZE=$(du -sm "$HOST_ROS2_SRC" 2>/dev/null | cut -f1)
else
    ROS2_SRC_SIZE=0
fi

TOTAL_COPY_SIZE=$((ROS2_SIZE + WS_SIZE + LOCAL_SIZE + ROS2_SRC_SIZE))

log_info "Space breakdown:"
log_info "  ROS 2 Jazzy install: ${ROS2_SIZE}MB"
log_info "  Workspace (/ws): ${WS_SIZE}MB"
log_info "  Python packages (.local): ${LOCAL_SIZE}MB"
if [ "$INCLUDE_ROS2_SRC" = true ]; then
    log_info "  ROS 2 source: ${ROS2_SRC_SIZE}MB"
fi
log_info "  Total to copy: ${TOTAL_COPY_SIZE}MB"
log_info "  Extra buffer: ${EXTRA_SPACE_GB}GB"
echo ""

################################################################################
# Cleanup Function
################################################################################

LOOP_DEV=""

cleanup() {
    log_info "Cleaning up mounts..."
    sync 2>/dev/null || true
    
    # Unmount in reverse order
    for mnt in "${MOUNT_DIR}/boot/firmware" "${MOUNT_DIR}/proc" "${MOUNT_DIR}/sys" "${MOUNT_DIR}/dev/pts" "${MOUNT_DIR}/dev" "$MOUNT_DIR"; do
        if mountpoint -q "$mnt" 2>/dev/null; then
            umount -l "$mnt" 2>/dev/null || true
        fi
    done
    
    # Release loop device
    if [ -n "$LOOP_DEV" ] && [ -e "$LOOP_DEV" ]; then
        kpartx -d "$LOOP_DEV" 2>/dev/null || true
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
}

trap cleanup EXIT

################################################################################
# Stage 1: Setup Directories
################################################################################

log_step "[1/10] Setting up directories..."

# Clean previous mounts first
cleanup
LOOP_DEV=""

mkdir -p "$WORK_DIR" "$OUTPUT_DIR" "$MOUNT_DIR"
log_success "Directories ready"

################################################################################
# Stage 2: Download/Prepare Base Image
################################################################################

log_step "[2/10] Preparing Raspberry Pi OS (Bookworm) base image..."

BASE_IMAGE_PATH="${WORK_DIR}/${BASE_IMAGE_NAME}"
BASE_IMAGE_XZ="${WORK_DIR}/$(basename $BASE_IMAGE_URL)"

# Download if needed
if [ ! -f "$BASE_IMAGE_PATH" ]; then
    if [ ! -f "$BASE_IMAGE_XZ" ]; then
        log_info "Downloading Raspberry Pi OS Lite ARM64 (Debian Bookworm based)..."
        log_warning "This is ~500MB, may take a while..."
        wget --show-progress -O "$BASE_IMAGE_XZ" "$BASE_IMAGE_URL"
    fi
    
    log_info "Extracting image (this preserves the .xz file)..."
    xz -d -k "$BASE_IMAGE_XZ"
    
    # Find and rename extracted image
    EXTRACTED=$(find "$WORK_DIR" -maxdepth 1 -name "*.img" -type f 2>/dev/null | head -1)
    if [ -n "$EXTRACTED" ] && [ "$EXTRACTED" != "$BASE_IMAGE_PATH" ]; then
        mv "$EXTRACTED" "$BASE_IMAGE_PATH"
    fi
fi

if [ ! -f "$BASE_IMAGE_PATH" ]; then
    log_error "Base image not found after extraction"
    exit 1
fi

log_success "Base image ready: $BASE_IMAGE_PATH"

################################################################################
# Stage 3: Resize Image
################################################################################

log_step "[3/10] Resizing image to fit ROS 2 + workspace..."

# Calculate required space
EXTRA_MB=$((EXTRA_SPACE_GB * 1024))
TOTAL_EXTRA_MB=$((TOTAL_COPY_SIZE + EXTRA_MB))

log_info "Total expansion needed: ${TOTAL_EXTRA_MB}MB (~$((TOTAL_EXTRA_MB / 1024))GB)"

# Expand the image file
truncate -s +${TOTAL_EXTRA_MB}M "$BASE_IMAGE_PATH"

# Setup loop device
LOOP_DEV=$(losetup -f --show -P "$BASE_IMAGE_PATH")
log_info "Loop device: $LOOP_DEV"

# Expand partition (partition 2 is root on Debian images)
parted -s "$LOOP_DEV" resizepart 2 100%

# Map partitions
kpartx -av "$LOOP_DEV"
sleep 2

LOOP_NAME=$(basename "$LOOP_DEV")
ROOT_DEV="/dev/mapper/${LOOP_NAME}p2"
BOOT_DEV="/dev/mapper/${LOOP_NAME}p1"

# Wait for devices
for i in {1..10}; do
    [ -e "$ROOT_DEV" ] && [ -e "$BOOT_DEV" ] && break
    sleep 1
done

if [ ! -e "$ROOT_DEV" ]; then
    log_error "Partition devices not found"
    exit 1
fi

# Expand filesystem
log_info "Expanding root filesystem..."
e2fsck -f -y "$ROOT_DEV" || true
resize2fs "$ROOT_DEV"

log_success "Image resized"

################################################################################
# Stage 4: Mount Image
################################################################################

log_step "[4/10] Mounting image..."

# Mount partitions
mount "$ROOT_DEV" "$MOUNT_DIR"
mkdir -p "${MOUNT_DIR}/boot/firmware"
mount "$BOOT_DEV" "${MOUNT_DIR}/boot/firmware"

log_success "Image mounted at $MOUNT_DIR"

################################################################################
# Stage 5: Copy ROS 2 Installation
################################################################################

log_step "[5/10] Copying ROS 2 Jazzy installation..."

# Create target directories
mkdir -p "${MOUNT_DIR}${PI_ROS2_INSTALL}"

# Copy ROS 2 installation
log_info "Copying ROS 2 Jazzy (${ROS2_SIZE}MB)..."
rsync -aHAX --info=progress2 \
    "$HOST_ROS2_INSTALL/" "${MOUNT_DIR}${PI_ROS2_INSTALL}/"

log_success "ROS 2 Jazzy installation copied"

# Optionally copy ROS 2 source
if [ "$INCLUDE_ROS2_SRC" = true ] && [ -d "$HOST_ROS2_SRC" ]; then
    log_info "Copying ROS 2 source (${ROS2_SRC_SIZE}MB)..."
    mkdir -p "${MOUNT_DIR}${PI_ROS2_SRC}"
    rsync -aHAX --info=progress2 \
        --exclude='build' \
        --exclude='log' \
        "$HOST_ROS2_SRC/" "${MOUNT_DIR}${PI_ROS2_SRC}/"
    log_success "ROS 2 source copied"
fi

################################################################################
# Stage 6: Copy User Workspace and Configuration
################################################################################

log_step "[6/10] Copying user workspace and configuration..."

# Create user home directory structure
mkdir -p "${MOUNT_DIR}${PI_HOME}"
mkdir -p "${MOUNT_DIR}${PI_USER_WS}"

if [ "$INCLUDE_FULL_WS" = true ]; then
    # Copy entire /ws folder
    log_info "Copying entire workspace folder (${WS_SIZE}MB)..."
    rsync -aHAX --info=progress2 \
        --exclude='.git' \
        --exclude='log/*' \
        --exclude='build/*/CMakeFiles' \
        "$HOST_USER_WS/" "${MOUNT_DIR}${PI_USER_WS}/"
    log_success "Entire workspace copied"
else
    # Copy only UGV workspace
    UGV_SIZE=$(du -sm "$HOST_UGV_WS" 2>/dev/null | cut -f1)
    log_info "Copying UGV workspace (${UGV_SIZE}MB)..."
    rsync -aHAX --info=progress2 \
        --exclude='.git' \
        --exclude='log/*' \
        --exclude='build/*/CMakeFiles' \
        "$HOST_UGV_WS/" "${MOUNT_DIR}${PI_UGV_WS}/"
    log_success "UGV workspace copied"
    
    # Copy CyberWave Edge ROS repository
    if [ -d "$HOST_CYBERWAVE" ]; then
        log_info "Copying CyberWave Edge ROS repository..."
        rsync -aHAX --info=progress2 \
            --exclude='.git' \
            "$HOST_CYBERWAVE/" "${MOUNT_DIR}${PI_CYBERWAVE}/"
        log_success "CyberWave repository copied"
    fi
fi

# Copy Python packages (.local)
if [ -d "$HOST_LOCAL" ]; then
    log_info "Copying Python packages (${LOCAL_SIZE}MB)..."
    mkdir -p "${MOUNT_DIR}${PI_HOME}/.local"
    rsync -aHAX --info=progress2 \
        --exclude='share/Trash' \
        --exclude='state' \
        "$HOST_LOCAL/" "${MOUNT_DIR}${PI_HOME}/.local/"
    log_success "Python packages copied"
fi

# Copy helper scripts from workspace
if [ -f "${HOST_USER_WS}/copy_mqtt_bridge.sh" ]; then
    cp "${HOST_USER_WS}/copy_mqtt_bridge.sh" "${MOUNT_DIR}${PI_USER_WS}/"
fi

if [ -f "${ACTUAL_HOME}/setup_ros.sh" ]; then
    cp "${ACTUAL_HOME}/setup_ros.sh" "${MOUNT_DIR}${PI_HOME}/"
fi

################################################################################
# Stage 7: System Configuration (from cyb-ugv-builder.sh)
################################################################################

log_step "[7/10] Applying system configurations (from cyb-ugv-builder.sh)..."

# Set hostname
echo "cyberwave-ugv-beast" > "${MOUNT_DIR}/etc/hostname"

# Update hosts file
cat > "${MOUNT_DIR}/etc/hosts" <<EOF
127.0.0.1       localhost
127.0.1.1       cyberwave-ugv-beast

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

log_info "Configured hostname: cyberwave-ugv-beast"

# Configure user .bashrc with ROS 2 environment (from cyb-ugv-builder.sh)
BASHRC="${MOUNT_DIR}${PI_HOME}/.bashrc"

# Create or update .bashrc
cat > "$BASHRC" <<'BASHRC_EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Check window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# === ROS 2 Jazzy Configuration (Cyberwave UGV Beast) ===

# Source ROS 2 Jazzy
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
fi

# Source UGV workspace (with error suppression for incomplete packages)
if [ -f ~/ws/ugv_ws/install/setup.bash ]; then
    source ~/ws/ugv_ws/install/setup.bash 2>/dev/null || source ~/ws/ugv_ws/install/setup.bash
fi

# Enable tab completion for ROS 2 and colcon
eval "$(register-python-argcomplete ros2)" 2>/dev/null || true
eval "$(register-python-argcomplete colcon)" 2>/dev/null || true

# Suppress Python deprecation warnings
export PYTHONWARNINGS="ignore::DeprecationWarning"

# Add local Python packages to PATH
export PATH="$HOME/.local/bin:$PATH"

# Default UGV model (can be: ugv_rover, ugv_beast, rasp_rover)
export UGV_MODEL=ugv_beast

# ROS 2 Domain ID (change if needed for multi-robot setups)
export ROS_DOMAIN_ID=0

# Helpful aliases for ROS 2
alias ros2_ws='cd ~/ws/ugv_ws'
alias ros2_build='cd ~/ws/ugv_ws && colcon build --symlink-install'
alias ros2_clean='cd ~/ws/ugv_ws && rm -rf build install log'

# === End ROS 2 Configuration ===
BASHRC_EOF

log_info "Configured .bashrc with ROS 2 environment"

# Create udev rules for serial ports (from cyb-ugv-builder.sh)
mkdir -p "${MOUNT_DIR}/etc/udev/rules.d"
echo 'KERNEL=="tty[A-Z]*[0-9]*", MODE="0666"' > "${MOUNT_DIR}/etc/udev/rules.d/99-serial.rules"
log_info "Created serial port udev rules"

# Create ALSA audio configuration (from cyb-ugv-builder.sh)
cat > "${MOUNT_DIR}/etc/asound.conf" <<'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF
log_info "Created ALSA audio configuration"

# Create Docker daemon configuration (from cyb-ugv-builder.sh)
mkdir -p "${MOUNT_DIR}/etc/docker"
cat > "${MOUNT_DIR}/etc/docker/daemon.json" <<'EOF'
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
log_info "Created Docker daemon configuration"

# Configure swap file (from cyb-ugv-builder.sh)
# Add swap configuration to fstab
if ! grep -q "swapfile" "${MOUNT_DIR}/etc/fstab"; then
    echo '/swapfile none swap sw 0 0' >> "${MOUNT_DIR}/etc/fstab"
fi
log_info "Configured swap in fstab"

# Create version info file
cat > "${MOUNT_DIR}/etc/cyberwave_ugv_info.txt" <<EOF
==============================================
Cyberwave UGV Beast Image
==============================================
Build Date: $(date)
Build Host: $(hostname)
Source User: ${ACTUAL_USER}

Base OS: Raspberry Pi OS Lite (Debian Bookworm/12)
ROS Distribution: ROS 2 Jazzy Jalisco
ROS Install: ${PI_ROS2_INSTALL}
UGV Workspace: ${PI_UGV_WS}

This image includes:
  - Pre-built ROS 2 Jazzy (from source)
  - Pre-built UGV workspace (29+ packages)
  - CyberWave Edge ROS integration
  - Python packages for UGV operation
  - System configurations (serial, audio, docker)
  - Network configuration (static IP ready)
  - All configurations from cyb-ugv-builder.sh

No compilation needed - ready to run!
==============================================
EOF

# Copy start script if exists
if [ -f "${HOST_UGV_WS}/start_ugv.sh" ]; then
    cp "${HOST_UGV_WS}/start_ugv.sh" "${MOUNT_DIR}${PI_UGV_WS}/"
    chmod +x "${MOUNT_DIR}${PI_UGV_WS}/start_ugv.sh"
    log_info "Copied start_ugv.sh"
fi

# Copy service installer if exists
if [ -f "${HOST_UGV_WS}/ugv_services_install.sh" ]; then
    cp "${HOST_UGV_WS}/ugv_services_install.sh" "${MOUNT_DIR}${PI_UGV_WS}/"
    chmod +x "${MOUNT_DIR}${PI_UGV_WS}/ugv_services_install.sh"
    log_info "Copied ugv_services_install.sh"
fi

# Create setup_ros.sh helper script
cat > "${MOUNT_DIR}${PI_HOME}/setup_ros.sh" <<'EOF'
#!/bin/bash
# Quick ROS 2 environment setup script

# Source ROS 2 Jazzy
if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
else
    echo "ERROR: ROS 2 Jazzy not found!"
    return 1
fi

# Source UGV workspace
if [ -f ~/ws/ugv_ws/install/setup.bash ]; then
    source ~/ws/ugv_ws/install/setup.bash
fi

# Set defaults
export UGV_MODEL=${UGV_MODEL:-ugv_beast}
export PYTHONWARNINGS="ignore::DeprecationWarning"
export PATH="$HOME/.local/bin:$PATH"

echo "✓ ROS 2 Jazzy environment loaded"
echo "  ROS_DISTRO: $ROS_DISTRO"
echo "  UGV_MODEL: $UGV_MODEL"
echo "  Workspace: ~/ws/ugv_ws"
EOF
chmod +x "${MOUNT_DIR}${PI_HOME}/setup_ros.sh"

# Enable SSH by default
touch "${MOUNT_DIR}/boot/firmware/ssh"
log_info "Enabled SSH"

################################################################################
# Stage 8: Boot Configuration (from cyb-ugv-builder.sh)
################################################################################

log_step "[8/10] Configuring boot settings (from cyb-ugv-builder.sh)..."

BOOT_CONFIG="${MOUNT_DIR}/boot/firmware/config.txt"
if [ -f "$BOOT_CONFIG" ]; then
    # Backup original
    cp "$BOOT_CONFIG" "${BOOT_CONFIG}.original"
    
    # Add ROS 2 realtime configuration if not present
    if ! grep -q "# === ROS 2 Realtime Configuration" "$BOOT_CONFIG" 2>/dev/null; then
        cat >> "$BOOT_CONFIG" <<'BOOT_EOF'

# === ROS 2 Realtime Configuration (Cyberwave UGV Beast) ===
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
BOOT_EOF
        log_info "  Added ROS 2 boot configuration"
    fi
fi

# Configure cmdline.txt for serial port access
BOOT_CMDLINE="${MOUNT_DIR}/boot/firmware/cmdline.txt"
if [ -f "$BOOT_CMDLINE" ]; then
    # Remove serial console to free up UART for ROS
    sed -i 's/console=serial0,[0-9]*//g' "$BOOT_CMDLINE"
    sed -i 's/console=ttyAMA0,[0-9]*//g' "$BOOT_CMDLINE"
    # Add plymouth setting if not present
    if ! grep -q "plymouth.ignore-serial-consoles" "$BOOT_CMDLINE"; then
        sed -i 's/$/ plymouth.ignore-serial-consoles/' "$BOOT_CMDLINE"
    fi
    log_info "  Configured cmdline.txt for serial access"
fi

# Set ownership for pi user (UID 1000)
chown -R 1000:1000 "${MOUNT_DIR}${PI_HOME}"

# Set correct ownership for /opt/ros
chown -R root:root "${MOUNT_DIR}/opt/ros"
chmod -R 755 "${MOUNT_DIR}/opt/ros"

log_success "Boot configuration complete"

################################################################################
# Stage 9: Network Configuration (from cyb-ugv-builder.sh)
################################################################################

log_step "[9/10] Configuring network (from cyb-ugv-builder.sh)..."

# Configure dhcpcd for static IP (Raspberry Pi OS uses dhcpcd)
if [ -f "${MOUNT_DIR}/etc/dhcpcd.conf" ]; then
    if ! grep -q "interface eth0" "${MOUNT_DIR}/etc/dhcpcd.conf"; then
        cat >> "${MOUNT_DIR}/etc/dhcpcd.conf" <<'EOF'

# === Static IP Configuration (Added by image builder) ===
interface eth0
static ip_address=192.168.0.144/24
static routers=192.168.0.1
static domain_name_servers=8.8.8.8 1.1.1.1
EOF
        log_info "Configured static IP (192.168.0.144/24) in dhcpcd.conf"
    fi
fi

# Also create netplan configuration for compatibility
mkdir -p "${MOUNT_DIR}/etc/netplan"
cat > "${MOUNT_DIR}/etc/netplan/50-cloud-init.yaml" <<'EOF'
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
log_info "Created netplan configuration (backup)"

log_success "Network configuration complete"

################################################################################
# Stage 10: Create First Boot Script
################################################################################

log_step "[10/10] Creating first boot configuration script..."

# Create a first-boot script that runs on first login
cat > "${MOUNT_DIR}${PI_HOME}/first_boot_config.sh" <<'FIRSTBOOT_EOF'
#!/bin/bash
################################################################################
# First Boot Configuration Script
# Run this once after first boot to complete the setup
################################################################################

set -e

echo "========================================"
echo "Cyberwave UGV Beast - First Boot Setup"
echo "========================================"
echo ""
echo "This script will:"
echo "  - Add user to hardware groups"
echo "  - Install required system packages"
echo "  - Configure Docker"
echo "  - Setup serial port permissions"
echo "  - Create swap file (2GB)"
echo "  - Disable unnecessary services"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Please run without sudo: ./first_boot_config.sh"
    exit 1
fi

echo ""
echo "[1/8] Adding user to hardware groups..."
sudo usermod -aG dialout,audio,video,plugdev $USER 2>/dev/null || true

# Add Pi-specific groups if they exist
for group in gpio i2c spi netdev docker; do
    if getent group $group >/dev/null 2>&1; then
        sudo usermod -aG $group $USER
        echo "  Added to group: $group"
    fi
done

echo ""
echo "[2/8] Updating package lists..."
sudo apt-get update

echo ""
echo "[3/8] Installing system packages..."
sudo apt-get install -y \
    python3-pip python3-venv python3-argcomplete python3-dev \
    git curl wget htop vim nano \
    build-essential cmake pkg-config \
    docker.io docker-compose \
    minicom screen setserial \
    alsa-utils \
    i2c-tools \
    libraspberrypi-bin \
    v4l-utils \
    || echo "Some packages may have failed (non-critical)"

echo ""
echo "[4/8] Creating 2GB swap file..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "  ✓ Swap file created and enabled"
else
    echo "  Swap file already exists"
    if ! swapon --show | grep -q "/swapfile"; then
        sudo swapon /swapfile
        echo "  ✓ Swap file enabled"
    fi
fi

echo ""
echo "[5/8] Enabling Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

echo ""
echo "[6/8] Configuring serial port permissions..."
# Create udev rule if not exists
if [ ! -f /etc/udev/rules.d/99-serial.rules ]; then
    echo 'KERNEL=="tty[A-Z]*[0-9]*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-serial.rules
fi
sudo udevadm control --reload-rules
sudo udevadm trigger
# Set permissions on existing devices
sudo chmod 666 /dev/ttyACM* /dev/ttyAMA* /dev/ttyUSB* /dev/ttyS* 2>/dev/null || true

echo ""
echo "[7/8] Disabling unnecessary services for ROS..."
# Disable Bluetooth service (UART freed for ROS)
sudo systemctl disable hciuart.service 2>/dev/null || true
sudo systemctl disable bluetooth.service 2>/dev/null || true
sudo systemctl mask serial-getty@ttyAMA0.service 2>/dev/null || true
sudo systemctl mask serial-getty@serial0.service 2>/dev/null || true

echo ""
echo "[8/8] Updating library cache..."
sudo ldconfig

# Verify ROS 2 installation
echo ""
echo "========================================"
echo "Verifying ROS 2 installation..."
echo "========================================"

if [ -f /opt/ros/jazzy/setup.bash ]; then
    source /opt/ros/jazzy/setup.bash
    echo "  ROS_DISTRO: $ROS_DISTRO"
    echo "  ROS_VERSION: $ROS_VERSION"
    
    if [ -f ~/ws/ugv_ws/install/setup.bash ]; then
        source ~/ws/ugv_ws/install/setup.bash 2>/dev/null || true
        PKG_COUNT=$(ros2 pkg list 2>/dev/null | wc -l)
        echo "  Workspace packages: $PKG_COUNT"
    fi
else
    echo "  WARNING: ROS 2 Jazzy not found at /opt/ros/jazzy"
fi

echo ""
echo "========================================"
echo "First boot configuration complete!"
echo "========================================"
echo ""
echo "IMPORTANT: Please reboot for all changes to take effect:"
echo "  sudo reboot"
echo ""
echo "After reboot, verify with:"
echo "  source ~/.bashrc"
echo "  ros2 pkg list | grep ugv"
echo ""
echo "To start UGV Beast:"
echo "  ros2 launch ugv_bringup master_beast.launch.py"
echo ""
echo "To install as systemd service (auto-start on boot):"
echo "  cd ~/ws/ugv_ws"
echo "  sudo ./ugv_services_install.sh"
echo ""
FIRSTBOOT_EOF

chmod +x "${MOUNT_DIR}${PI_HOME}/first_boot_config.sh"
chown 1000:1000 "${MOUNT_DIR}${PI_HOME}/first_boot_config.sh"

log_success "First boot script created"

################################################################################
# Finalize
################################################################################

log_info "Syncing filesystem..."
sync

log_info "Unmounting image..."
umount "${MOUNT_DIR}/boot/firmware"
umount "$MOUNT_DIR"

log_info "Releasing loop device..."
kpartx -d "$LOOP_DEV"
losetup -d "$LOOP_DEV"
LOOP_DEV=""

# Move to output
FINAL_IMAGE="${OUTPUT_DIR}/${OUTPUT_IMAGE_NAME}"
mv "$BASE_IMAGE_PATH" "$FINAL_IMAGE"

# Generate checksum
log_info "Generating SHA256 checksum..."
sha256sum "$FINAL_IMAGE" > "${FINAL_IMAGE}.sha256"

# Calculate final size
FINAL_SIZE=$(stat -c%s "$FINAL_IMAGE")
FINAL_SIZE_GB=$(echo "scale=2; $FINAL_SIZE / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "$((FINAL_SIZE / 1024 / 1024))MB")

################################################################################
# Success Summary
################################################################################

echo ""
log_success "========================================"
log_success "IMAGE BUILD COMPLETE!"
log_success "========================================"
echo ""
log_info "Output: $FINAL_IMAGE"
log_info "Size: ${FINAL_SIZE_GB}"
log_info "Checksum: ${FINAL_IMAGE}.sha256"
echo ""
log_info "========================================"
log_info "Image Contents:"
log_info "========================================"
log_info "  Base OS: Raspberry Pi OS Lite (Debian Bookworm)"
log_info "  ROS 2: Jazzy Jalisco (pre-built)"
log_info "  UGV Workspace: Pre-built (29+ packages)"
log_info "  CyberWave: Edge ROS integration"
log_info "  Python: Packages in ~/.local"
log_info "  Configurations: From cyb-ugv-builder.sh"
echo ""
log_info "========================================"
log_info "Configurations Included:"
log_info "========================================"
log_info "  ✓ Boot configuration (UART, performance)"
log_info "  ✓ Serial port permissions (udev rules)"
log_info "  ✓ Audio configuration (ALSA)"
log_info "  ✓ Docker daemon configuration"
log_info "  ✓ Network configuration (static IP: 192.168.0.144/24)"
log_info "  ✓ Swap file configuration (2GB)"
log_info "  ✓ SSH enabled"
log_info "  ✓ ROS 2 environment (.bashrc)"
echo ""
log_info "========================================"
log_info "To flash to SD card:"
log_info "========================================"
log_info "  sudo dd if=$FINAL_IMAGE of=/dev/sdX bs=4M status=progress"
log_info "  (Replace /dev/sdX with your SD card device)"
echo ""
log_info "Or use: Raspberry Pi Imager / balenaEtcher"
echo ""
log_info "========================================"
log_info "After first boot:"
log_info "========================================"
log_info "  1. Login as 'pi' (or your configured user)"
log_info "  2. Run: ./first_boot_config.sh"
log_info "  3. Reboot: sudo reboot"
log_info "  4. Verify: ros2 pkg list | head"
echo ""
log_info "  Hostname: cyberwave-ugv-beast"
log_info "  SSH: Enabled"
log_info "  Static IP: 192.168.0.144/24"
log_info "  ROS 2: Ready to use (no build needed!)"
echo ""
log_info "========================================"
log_info "Quick Start Commands:"
log_info "========================================"
log_info "  # Source environment (auto-loaded in .bashrc)"
log_info "  source ~/.bashrc"
echo ""
log_info "  # List ROS 2 packages"
log_info "  ros2 pkg list | grep ugv"
echo ""
log_info "  # Launch UGV Beast"
log_info "  ros2 launch ugv_bringup master_beast.launch.py"
echo ""
log_info "  # Or use start script"
log_info "  cd ~/ws/ugv_ws && ./start_ugv.sh"
echo ""
log_info "  # Install as systemd service (auto-start on boot)"
log_info "  cd ~/ws/ugv_ws && sudo ./ugv_services_install.sh"
echo ""

trap - EXIT
exit 0
