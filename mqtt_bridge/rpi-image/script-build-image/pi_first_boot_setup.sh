#!/bin/bash
################################################################################
# Cyberwave UGV Beast - Pi First Boot Setup
#
# Run this script ON THE RASPBERRY PI after first boot to install
# ROS 2 runtime dependencies.
#
# Usage (on the Pi):
#   sudo bash pi_first_boot_setup.sh
#
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "========================================"
log_info "Cyberwave UGV Beast - First Boot Setup"
log_info "========================================"
echo ""

################################################################################
# System Update
################################################################################

log_info "Updating system packages..."
apt-get update
apt-get upgrade -y

################################################################################
# Add ROS 2 Repository
################################################################################

log_info "Adding ROS 2 repository..."

# Install prerequisites
apt-get install -y curl gnupg2 lsb-release software-properties-common

# Add ROS 2 GPG key
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Detect Ubuntu/Debian codename
if [ -f /etc/os-release ]; then
    . /etc/os-release
    CODENAME=$VERSION_CODENAME
else
    CODENAME=$(lsb_release -cs)
fi

# For Raspberry Pi OS Bookworm, use Ubuntu Jammy packages (compatible)
# ROS 2 Humble is for Ubuntu 22.04 (Jammy)
# ROS 2 Jazzy is for Ubuntu 24.04 (Noble) - but not widely available for arm64 yet

log_info "Detected OS codename: $CODENAME"

# Add ROS 2 repository (using Jammy for Humble compatibility)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" > /etc/apt/sources.list.d/ros2.list

apt-get update

################################################################################
# Install ROS 2 Runtime (Binary packages - NO compilation)
################################################################################

log_info "Installing ROS 2 Humble runtime packages..."
log_warning "This will download ~500MB of packages..."

# Install ROS 2 Humble base (runtime only, not full desktop)
apt-get install -y \
    ros-humble-ros-base \
    ros-humble-rmw-cyclonedds-cpp \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-argcomplete

log_success "ROS 2 Humble runtime installed"

################################################################################
# Install Common Dependencies for UGV
################################################################################

log_info "Installing common UGV dependencies..."

apt-get install -y \
    python3-pip \
    python3-serial \
    i2c-tools \
    libi2c-dev \
    pigpio \
    libpigpio-dev \
    libraspberrypi-bin \
    || log_warning "Some packages may not be available, continuing..."

# Python packages
pip3 install --break-system-packages \
    pyserial \
    RPi.GPIO \
    smbus2 \
    paho-mqtt \
    || log_warning "Some pip packages may have failed, continuing..."

################################################################################
# Initialize rosdep
################################################################################

log_info "Initializing rosdep..."

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    rosdep init || true
fi

# Run as the pi user
su - pi -c "rosdep update" || true

################################################################################
# Setup Environment
################################################################################

log_info "Setting up environment..."

# Add to pi user's .bashrc if not already there
BASHRC="/home/pi/.bashrc"

if ! grep -q "ros-humble" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" <<'EOF'

# ROS 2 Humble
source /opt/ros/humble/setup.bash

# UGV Workspace (if exists)
if [ -f /home/pi/ugv_ws/install/setup.bash ]; then
    source /home/pi/ugv_ws/install/setup.bash
fi

# CycloneDDS for better networking
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
export ROS_DOMAIN_ID=0
EOF
fi

################################################################################
# Enable Hardware Interfaces
################################################################################

log_info "Enabling hardware interfaces..."

# Enable I2C
if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
    echo "dtparam=i2c_arm=on" >> /boot/firmware/config.txt
fi

# Enable SPI
if ! grep -q "^dtparam=spi=on" /boot/firmware/config.txt 2>/dev/null; then
    echo "dtparam=spi=on" >> /boot/firmware/config.txt
fi

# Enable UART
if ! grep -q "^enable_uart=1" /boot/firmware/config.txt 2>/dev/null; then
    echo "enable_uart=1" >> /boot/firmware/config.txt
fi

# Add pi user to required groups
usermod -aG i2c,spi,gpio,dialout pi 2>/dev/null || true

################################################################################
# Cleanup
################################################################################

log_info "Cleaning up..."
apt-get autoremove -y
apt-get clean

################################################################################
# Done
################################################################################

echo ""
log_success "========================================"
log_success "FIRST BOOT SETUP COMPLETE!"
log_success "========================================"
echo ""
log_info "Please reboot to apply all changes:"
log_info "  sudo reboot"
echo ""
log_info "After reboot, test ROS 2:"
log_info "  source ~/.bashrc"
log_info "  ros2 --help"
echo ""
log_info "Start the UGV:"
log_info "  cd ~/ugv_ws"
log_info "  ./start_ugv.sh"
echo ""
