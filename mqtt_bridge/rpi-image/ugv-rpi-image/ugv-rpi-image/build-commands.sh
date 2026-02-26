#!/bin/bash
# Complete Build Machine Workflow - Step by Step Commands
# Copy and paste each section in order

echo "════════════════════════════════════════════════════════════════"
echo "UGV ROS 2 Jazzy Image Build - Complete Command Checklist"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Run these commands ON YOUR BUILD MACHINE (not Raspberry Pi)"
echo ""

# ============================================================================
# STEP 0: ONE-TIME SETUP (if not already done)
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 0: One-Time Build Machine Setup"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Install Docker"
echo "curl -fsSL https://get.docker.com -o get-docker.sh"
echo "sudo sh get-docker.sh"
echo "sudo usermod -aG docker \$USER"
echo "echo 'Log out and back in after this!'"
echo ""
echo "# Install dependencies"
echo "sudo apt update"
echo "sudo apt install -y git wget qemu-user-static binfmt-support rsync"
echo ""
echo "# Clone rpi-image-gen"
echo "cd ~"
echo "git clone https://github.com/raspberrypi/rpi-image-gen.git"
echo ""
echo "# Verify Docker"
echo "docker --version"
echo "docker ps"
echo ""

# ============================================================================
# STEP 1: COPY CONFIGURATION FROM RASPBERRY PI
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 1: Copy ugv-rpi-image from Raspberry Pi to Build Machine"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Set your Raspberry Pi IP address"
echo "export PI_IP=192.168.1.100  # CHANGE THIS to your Pi's IP"
echo ""
echo "# Create workspace"
echo "mkdir -p ~/ugv-build"
echo "cd ~/ugv-build"
echo ""
echo "# Copy from Raspberry Pi (choose ONE method):"
echo ""
echo "# Method A: Using scp"
echo "scp -r ubuntu@\$PI_IP:/home/ubuntu/ws/ugv-rpi-image ./"
echo ""
echo "# OR Method B: Using rsync (preserves permissions)"
echo "rsync -avz ubuntu@\$PI_IP:/home/ubuntu/ws/ugv-rpi-image/ ./ugv-rpi-image/"
echo ""
echo "# OR Method C: Using tar (for large transfers)"
echo "# On Pi: cd /home/ubuntu/ws && tar czf ugv-rpi-image.tar.gz ugv-rpi-image/"
echo "# Then:  scp ubuntu@\$PI_IP:/home/ubuntu/ws/ugv-rpi-image.tar.gz ./"
echo "#        tar xzf ugv-rpi-image.tar.gz"
echo ""
echo "# Verify it copied"
echo "ls -la ugv-rpi-image/"
echo "ls -la ugv-rpi-image/layers/"
echo ""

# ============================================================================
# STEP 2: ADD YOUR LOCAL FILES
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 2: Add Your Local Files (mqtt_bridge, custom configs, etc.)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Navigate to custom files directory"
echo "cd ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files"
echo ""
echo "# Copy your mqtt_bridge folder"
echo "# REPLACE /path/to/your/mqtt_bridge with your actual path!"
echo "cp -r /path/to/your/mqtt_bridge ./"
echo ""
echo "# Example: If mqtt_bridge is in ~/projects/"
echo "# cp -r ~/projects/mqtt_bridge ./"
echo ""
echo "# Copy other custom files if needed"
echo "# cp -r ~/projects/custom_launch_files ./ugv_beast/launch/"
echo "# cp -r ~/projects/custom_scripts ./"
echo ""
echo "# Verify files are there"
echo "ls -la mqtt_bridge/"
echo "ls -la ugv_beast/"
echo ""

# ============================================================================
# STEP 3: CONFIGURE FILE MAPPINGS
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 3: Configure File Mappings in config.yaml"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Edit the custom files layer config"
echo "cd ~/ugv-build/ugv-rpi-image/layers/50-custom-files"
echo "nano config.yaml"
echo ""
echo "# Add your file mappings (example below):"
cat << 'EOF'

# ──────────────────────────────────────────────────────────────────
# Example config.yaml entries for mqtt_bridge:
# ──────────────────────────────────────────────────────────────────

files:
  # ... existing ugv_beast files ...
  
  # MQTT Bridge configuration
  - src: files/mqtt_bridge/config/mqtt_config.yaml
    dest: /home/ubuntu/ws/ugv_ws/config/mqtt_config.yaml
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # MQTT Bridge main script
  - src: files/mqtt_bridge/scripts/mqtt_bridge.py
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/mqtt_bridge.py
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # MQTT Bridge test script
  - src: files/mqtt_bridge/scripts/mqtt_test.py
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/mqtt_test.py
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # Systemd service
  - src: files/mqtt_bridge/systemd/mqtt-bridge.service
    dest: /etc/systemd/system/mqtt-bridge.service
    mode: "0644"
    owner: root
    group: root

# Optional: Install MQTT packages
packages:
  - mosquitto
  - mosquitto-clients
  - python3-paho-mqtt

# Optional: Enable service
commands:
  - systemctl daemon-reload
  - systemctl enable mqtt-bridge.service
  - pip3 install paho-mqtt

# ──────────────────────────────────────────────────────────────────
EOF

echo ""
echo "Press Ctrl+O to save, Ctrl+X to exit nano"
echo ""

# ============================================================================
# STEP 4: CREATE MAIN CONFIG (if not exists)
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 4: Verify/Create Main config.yaml"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Check if main config exists"
echo "cd ~/ugv-build/ugv-rpi-image"
echo "ls -la config.yaml"
echo ""
echo "# If config.yaml doesn't exist, create it:"
echo "# (Otherwise skip this)"
cat << 'EOF'

# Create main config.yaml
cat > config.yaml << 'MAINCONFIG'
name: "ugv-ros2-jazzy"
version: "1.0.0"
description: "Custom Raspberry Pi OS image for UGV with ROS 2 Jazzy"

base:
  image: "ubuntu-24.04-preinstalled-server-arm64+raspi.img.xz"
  url: "https://cdimage.ubuntu.com/releases/24.04/release/"

target:
  architecture: arm64

size: 16G

layers:
  - 00-base
  - 10-ros2-jazzy
  - 20-ugv-system
  - 30-ugv-workspace
  - 40-ugv-apps
  - 50-custom-files

user:
  name: ubuntu
  password: ubuntu
  groups:
    - sudo
    - dialout
    - docker
    - gpio
    - i2c
    - spi
    - audio
    - video
    - plugdev

network:
  hostname: ugv-robot
  ssh:
    enabled: true

build:
  parallel: true
  cache: true
  compression: xz
MAINCONFIG

EOF

echo ""

# ============================================================================
# STEP 5: VALIDATE CONFIGURATION
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 5: Validate Your Configuration"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Check main config"
echo "cd ~/ugv-build/ugv-rpi-image"
echo "cat config.yaml"
echo ""
echo "# Check custom files layer"
echo "cat layers/50-custom-files/config.yaml"
echo ""
echo "# Check your files are in place"
echo "ls -la layers/50-custom-files/files/"
echo "ls -la layers/50-custom-files/files/mqtt_bridge/"
echo ""
echo "# Run validation script (if exists)"
echo "bash layers/50-custom-files/validate.sh"
echo ""

# ============================================================================
# STEP 6: BUILD THE IMAGE
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 6: Build the Image (This takes 2-4 hours!)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Navigate to rpi-image-gen"
echo "cd ~/rpi-image-gen"
echo ""
echo "# Start the build (requires sudo)"
echo "sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml"
echo ""
echo "# ⏰ GO GET COFFEE! This will take 2-4 hours depending on your machine."
echo ""
echo "# Output will be in:"
echo "# ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz"
echo ""

# ============================================================================
# STEP 7: VERIFY BUILD
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 7: Verify Build Completed Successfully"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Check output file exists"
echo "ls -lh ~/rpi-image-gen/deploy/"
echo ""
echo "# Check file size (should be ~3-8GB compressed)"
echo "du -h ~/rpi-image-gen/deploy/*.img.xz"
echo ""
echo "# Verify integrity (optional)"
echo "sha256sum ~/rpi-image-gen/deploy/*.img.xz > image-checksum.txt"
echo "cat image-checksum.txt"
echo ""

# ============================================================================
# STEP 8: FLASH TO SD CARD
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 8: Flash Image to SD Card"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# OPTION A: Using dd (Linux/macOS)"
echo "# ─────────────────────────────────"
echo ""
echo "# Extract image"
echo "cd ~/rpi-image-gen/deploy"
echo "unxz ugv-ros2-jazzy-v1.0.0.img.xz"
echo ""
echo "# Find SD card device"
echo "lsblk"
echo "# Look for your SD card (usually /dev/sdX or /dev/mmcblkX)"
echo ""
echo "# ⚠️  WARNING: Double-check the device! Wrong device = data loss!"
echo "# Replace /dev/sdX with your actual SD card device"
echo "sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/sdX bs=4M status=progress conv=fsync"
echo ""
echo "# Sync to ensure write completes"
echo "sync"
echo ""
echo "# ─────────────────────────────────"
echo "# OPTION B: Using Raspberry Pi Imager (Easier!)"
echo "# ─────────────────────────────────"
echo ""
echo "# 1. Download: https://www.raspberrypi.com/software/"
echo "# 2. Run Raspberry Pi Imager"
echo "# 3. Choose OS → Use custom"
echo "# 4. Select: ugv-ros2-jazzy-v1.0.0.img.xz"
echo "# 5. Choose Storage → Your SD card"
echo "# 6. Click Write"
echo ""
echo "# ─────────────────────────────────"
echo "# OPTION C: Using Balena Etcher"
echo "# ─────────────────────────────────"
echo ""
echo "# 1. Download: https://etcher.balena.io/"
echo "# 2. Select image file"
echo "# 3. Select target SD card"
echo "# 4. Flash!"
echo ""

# ============================================================================
# STEP 9: BOOT AND VERIFY
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "STEP 9: Boot Raspberry Pi and Verify"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "# Insert SD card into Raspberry Pi and power on"
echo "# Wait ~2-3 minutes for first boot"
echo ""
echo "# SSH into the Pi"
echo "ssh ubuntu@<PI_IP>"
echo "# Default password: ubuntu (you'll be prompted to change it)"
echo ""
echo "# Once logged in, verify your files are there:"
echo ""
echo "# Check mqtt_bridge"
echo "ls -la /home/ubuntu/ws/ugv_ws/mqtt_bridge/"
echo ""
echo "# Check custom launch files"
echo "ls -la /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/"
echo ""
echo "# Check config files"
echo "ls -la /home/ubuntu/ws/ugv_ws/config/"
echo ""
echo "# Check systemd services"
echo "ls -la /etc/systemd/system/mqtt-bridge.service"
echo "systemctl status mqtt-bridge.service"
echo ""
echo "# Test ROS 2 workspace"
echo "source /opt/ros/jazzy/setup.bash"
echo "source /home/ubuntu/ws/ugv_ws/install/setup.bash"
echo "ros2 pkg list | grep ugv"
echo ""
echo "# Test launch"
echo "export UGV_MODEL=ugv_beast"
echo "ros2 launch ugv_bringup master_beast.launch.py"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "✅ COMPLETE WORKFLOW SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. ✅ Setup Build Machine (one-time)"
echo "2. ✅ Copy ugv-rpi-image from Pi"
echo "3. ✅ Add your local files (mqtt_bridge)"
echo "4. ✅ Configure file mappings"
echo "5. ✅ Verify configuration"
echo "6. ✅ Build image (2-4 hours)"
echo "7. ✅ Verify build output"
echo "8. ✅ Flash to SD card"
echo "9. ✅ Boot and verify"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "🎉 Done! Your custom UGV image is ready to deploy!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📚 Documentation:"
echo "   • Full workflow: ~/ugv-build/ugv-rpi-image/BUILD_MACHINE_WORKFLOW.md"
echo "   • Visual guide:  ~/ugv-build/ugv-rpi-image/BUILD_MACHINE_VISUAL_GUIDE.md"
echo "   • Quick start:   ~/ugv-build/ugv-rpi-image/QUICK_START_CUSTOM_FILES.md"
echo ""
