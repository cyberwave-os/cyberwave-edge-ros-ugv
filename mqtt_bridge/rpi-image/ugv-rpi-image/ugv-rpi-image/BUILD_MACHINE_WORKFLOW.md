# Building UGV Image from Build Machine

## Complete Workflow: From Build Machine to Flashed SD Card

This guide shows you how to build the UGV ROS 2 Jazzy image on your Build Machine (PC/laptop) using your local files like `mqtt_bridge/`.

---

## 🎯 Overview

**What you have:**
- **Raspberry Pi** (current system) with `ugv-rpi-image/` configuration
- **Build Machine** (your PC) with local files like `mqtt_bridge/`

**What you need to do:**
1. Copy `ugv-rpi-image/` from Raspberry Pi to Build Machine
2. Copy your local files (`mqtt_bridge/`, etc.) into the image configuration
3. Build the image using `rpi-image-gen`
4. Flash to SD card

---

## 📋 Prerequisites

### On Your Build Machine

```bash
# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in to apply group changes

# 2. Install dependencies
sudo apt update
sudo apt install -y git wget qemu-user-static binfmt-support

# 3. Clone rpi-image-gen
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
cd rpi-image-gen

# 4. Verify Docker is working
docker --version
docker ps
```

---

## 🚀 Step-by-Step Build Process

### Step 1: Copy ugv-rpi-image from Raspberry Pi to Build Machine

**On your Build Machine:**

```bash
# Create workspace directory
mkdir -p ~/ugv-build
cd ~/ugv-build

# Copy the entire ugv-rpi-image directory from Raspberry Pi
# Replace <PI_IP> with your Raspberry Pi's IP address
scp -r ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image ./

# Verify it copied
ls -la ugv-rpi-image/
```

**Example:**
```bash
scp -r ubuntu@192.168.1.100:/home/ubuntu/ws/ugv-rpi-image ./
```

**Alternative:** If you can't SCP, use rsync or manually transfer:
```bash
# Using rsync (preserves permissions)
rsync -avz ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image/ ./ugv-rpi-image/

# Or compress and transfer
# On Raspberry Pi:
cd /home/ubuntu/ws
tar czf ugv-rpi-image.tar.gz ugv-rpi-image/

# On Build Machine:
scp ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image.tar.gz ./
tar xzf ugv-rpi-image.tar.gz
```

---

### Step 2: Add Your Local Files (mqtt_bridge, etc.)

Now you have `ugv-rpi-image/` on your Build Machine. Add your local files:

#### Option A: Add to Custom Files Layer (Recommended)

```bash
cd ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files

# Copy your mqtt_bridge folder
cp -r /path/to/your/mqtt_bridge ./

# Verify structure
ls -la mqtt_bridge/
```

Then edit `layers/50-custom-files/config.yaml` to include the files:

```yaml
files:
  # ... existing files ...
  
  # MQTT Bridge configuration
  - src: files/mqtt_bridge/config/mqtt_config.yaml
    dest: /home/ubuntu/ws/ugv_ws/config/mqtt_config.yaml
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # MQTT Bridge scripts
  - src: files/mqtt_bridge/bridge.py
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/bridge.py
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # Copy entire mqtt_bridge directory (alternative)
  # - src: files/mqtt_bridge/
  #   dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/
  #   recursive: true
```

**Or use commands to copy entire directory:**

```yaml
commands:
  # Copy entire mqtt_bridge directory
  - mkdir -p /home/ubuntu/ws/ugv_ws/mqtt_bridge
  - rsync -av files/mqtt_bridge/ /home/ubuntu/ws/ugv_ws/mqtt_bridge/
  - chown -R ubuntu:ubuntu /home/ubuntu/ws/ugv_ws/mqtt_bridge/
```

#### Option B: Create a New Layer for MQTT Bridge

For better organization, create a dedicated layer:

```bash
cd ~/ugv-build/ugv-rpi-image/layers

# Create new layer
mkdir -p 51-mqtt-bridge/files
cd 51-mqtt-bridge

# Copy your mqtt_bridge
cp -r /path/to/your/mqtt_bridge files/

# Create config.yaml
cat > config.yaml << 'EOF'
name: "mqtt-bridge"
description: "MQTT Bridge for UGV communication"

# Install MQTT dependencies
packages:
  - mosquitto
  - mosquitto-clients
  - python3-paho-mqtt

# Copy MQTT Bridge files
files:
  - src: files/mqtt_bridge/
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/
    owner: ubuntu
    group: ubuntu
    recursive: true

# Install Python dependencies
commands:
  - pip3 install paho-mqtt python-mqtt
  
# Optional: Configure MQTT service
  # - cp files/mqtt_bridge/systemd/mqtt-bridge.service /etc/systemd/system/
  # - systemctl enable mqtt-bridge.service
EOF
```

Then add the layer to main `config.yaml`:

```bash
cd ~/ugv-build/ugv-rpi-image

# Create main config.yaml if it doesn't exist
cat > config.yaml << 'EOF'
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
  - 51-mqtt-bridge      # ADD THIS LINE

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
EOF
```

---

### Step 3: Verify Your Configuration

```bash
cd ~/ugv-build/ugv-rpi-image

# Check your custom files are in place
ls -la layers/50-custom-files/files/

# Check your mqtt_bridge is there
ls -la layers/50-custom-files/files/mqtt_bridge/
# OR
ls -la layers/51-mqtt-bridge/files/mqtt_bridge/

# Verify config.yaml exists
cat config.yaml

# Run validation (if you have the script)
bash layers/50-custom-files/validate.sh
```

**Example directory structure you should have:**

```
~/ugv-build/
└── ugv-rpi-image/
    ├── config.yaml                    ← Main config
    ├── scripts/
    │   ├── apply-fixes.sh
    │   ├── build-workspace.sh
    │   └── install-python.sh
    └── layers/
        ├── 00-base/
        ├── 10-ros2-jazzy/
        ├── 20-ugv-system/
        ├── 30-ugv-workspace/
        ├── 40-ugv-apps/
        ├── 50-custom-files/
        │   └── files/
        │       ├── ugv_beast/
        │       │   ├── master_beast.launch.py
        │       │   └── ...
        │       └── mqtt_bridge/        ← YOUR FILES HERE
        │           ├── config/
        │           ├── scripts/
        │           └── ...
        └── 51-mqtt-bridge/              ← OR HERE (optional)
            ├── config.yaml
            └── files/
                └── mqtt_bridge/
```

---

### Step 4: Build the Image

```bash
cd ~/rpi-image-gen

# Build the image
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# This will take 2-4 hours depending on your Build Machine specs
# Progress will be shown in terminal
```

**What happens during build:**
1. Downloads base Ubuntu 24.04 ARM64 image
2. Mounts image in Docker container
3. Executes each layer in order:
   - Installs base packages
   - Installs ROS 2 Jazzy
   - Configures UGV system (boot, serial, Docker, etc.)
   - Clones and builds ROS 2 workspace
   - Installs UGV apps
   - **Copies your custom files** (mqtt_bridge, launch files, etc.)
4. Compresses final image

**Build output:**
```
~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

---

### Step 5: Flash to SD Card

#### Option A: Using `dd` (Linux/macOS)

```bash
cd ~/rpi-image-gen/deploy

# Extract (if compressed)
unxz ugv-ros2-jazzy-v1.0.0.img.xz

# Find your SD card device
lsblk
# Look for your SD card (usually /dev/sdX or /dev/mmcblkX)

# Flash to SD card (CAREFUL! Double-check the device!)
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/sdX bs=4M status=progress conv=fsync

# Sync to ensure write is complete
sync
```

#### Option B: Using Raspberry Pi Imager (Easiest)

1. Download Raspberry Pi Imager: https://www.raspberrypi.com/software/
2. Run Raspberry Pi Imager
3. Choose OS → **Use custom**
4. Select your `ugv-ros2-jazzy-v1.0.0.img.xz`
5. Choose SD card
6. Click **Write**

#### Option C: Using Balena Etcher

1. Download Etcher: https://etcher.balena.io/
2. Select image file
3. Select target SD card
4. Flash!

---

### Step 6: Boot and Verify

```bash
# Insert SD card into Raspberry Pi and boot

# SSH into the Pi
ssh ubuntu@<PI_IP>
# Password: ubuntu (or what you set in config.yaml)

# Verify your files are there
ls -la /home/ubuntu/ws/ugv_ws/mqtt_bridge/
ls -la /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/

# Check ROS 2 workspace
source /opt/ros/jazzy/setup.bash
source /home/ubuntu/ws/ugv_ws/install/setup.bash
ros2 pkg list | grep ugv

# Test launch
export UGV_MODEL=ugv_beast
ros2 launch ugv_bringup master_beast.launch.py
```

---

## 🔄 Quick Reference Workflow

```bash
# === ON BUILD MACHINE ===

# 1. Copy configuration from Pi
cd ~/ugv-build
scp -r ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image ./

# 2. Add your local files
cp -r /path/to/mqtt_bridge ugv-rpi-image/layers/50-custom-files/files/

# 3. Edit config to include new files
nano ugv-rpi-image/layers/50-custom-files/config.yaml

# 4. Build image
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# 5. Flash to SD card
sudo dd if=deploy/ugv-ros2-jazzy-v1.0.0.img of=/dev/sdX bs=4M status=progress

# === ON RASPBERRY PI ===

# 6. Boot and verify
ssh ubuntu@<PI_IP>
ls -la /home/ubuntu/ws/ugv_ws/mqtt_bridge/
```

---

## 📝 Example: Adding MQTT Bridge Step by Step

Let's say you have this structure on your Build Machine:

```
~/projects/mqtt_bridge/
├── config/
│   └── mqtt_config.yaml
├── scripts/
│   ├── mqtt_bridge.py
│   └── mqtt_test.py
└── systemd/
    └── mqtt-bridge.service
```

### Step 1: Copy to image config

```bash
cd ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files

# Copy your entire mqtt_bridge folder
cp -r ~/projects/mqtt_bridge ./

# Check it's there
ls -la mqtt_bridge/
```

### Step 2: Configure file mappings

Edit `config.yaml`:

```yaml
# layers/50-custom-files/config.yaml

name: "custom-ugv-files"
description: "Custom UGV files including MQTT Bridge"

# Install MQTT packages
packages:
  - mosquitto
  - mosquitto-clients
  - python3-paho-mqtt

files:
  # UGV Beast files
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # ... other ugv_beast files ...
  
  # MQTT Bridge - Config
  - src: files/mqtt_bridge/config/mqtt_config.yaml
    dest: /home/ubuntu/ws/ugv_ws/config/mqtt_config.yaml
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # MQTT Bridge - Scripts
  - src: files/mqtt_bridge/scripts/mqtt_bridge.py
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/mqtt_bridge.py
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  - src: files/mqtt_bridge/scripts/mqtt_test.py
    dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/mqtt_test.py
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # MQTT Bridge - Systemd service
  - src: files/mqtt_bridge/systemd/mqtt-bridge.service
    dest: /etc/systemd/system/mqtt-bridge.service
    mode: "0644"
    owner: root
    group: root

commands:
  # Enable MQTT Bridge service
  - systemctl daemon-reload
  - systemctl enable mqtt-bridge.service
  
  # Install Python MQTT dependencies
  - pip3 install paho-mqtt
```

### Step 3: Build and flash

```bash
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# Wait for build to complete...
# Flash to SD card...
```

---

## 🔧 Troubleshooting

### Issue: "Permission denied" when building

**Solution:**
```bash
# Make sure you're using sudo
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# Or add your user to docker group
sudo usermod -aG docker $USER
# Then log out and back in
```

### Issue: "File not found" during build

**Solution:**
Check paths in `config.yaml` are relative to the layer directory:

```yaml
# ❌ Wrong:
src: ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files/mqtt_bridge/config.yaml

# ✅ Correct:
src: files/mqtt_bridge/config.yaml
```

### Issue: Files not appearing in final image

**Solution:**
1. Check layer is listed in main `config.yaml`:
   ```yaml
   layers:
     - 50-custom-files  # Must be here!
   ```

2. Check file paths are correct
3. Check build logs for errors:
   ```bash
   grep -i "error" ~/rpi-image-gen/build.log
   ```

### Issue: Build takes too long / hangs

**Solution:**
```bash
# Check Docker is running
docker ps

# Check available disk space
df -h

# Build with verbose output
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml --verbose
```

---

## 💡 Pro Tips

### Tip 1: Use Git for Version Control

```bash
cd ~/ugv-build/ugv-rpi-image
git init
git add .
git commit -m "Initial UGV image configuration"
git tag v1.0.0

# After making changes
git commit -am "Added MQTT Bridge"
git tag v1.1.0
```

### Tip 2: Test Incrementally

Build base image first, then add custom layers:

```bash
# Build just base system
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml --layers 00-base,10-ros2-jazzy

# If that works, add more layers
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml --layers 00-base,10-ros2-jazzy,20-ugv-system

# Finally, full build
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml
```

### Tip 3: Cache Layers

Enable caching to speed up rebuilds:

```yaml
# config.yaml
build:
  cache: true
```

Then only changed layers are rebuilt!

### Tip 4: Build in CI/CD

Automate builds in GitHub Actions:

```yaml
# .github/workflows/build-image.yml
name: Build UGV Image

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build image
        run: |
          git clone https://github.com/raspberrypi/rpi-image-gen.git
          cd rpi-image-gen
          sudo ./build.sh ../config.yaml
      - name: Upload artifact
        uses: actions/upload-artifact@v2
        with:
          name: ugv-image
          path: rpi-image-gen/deploy/*.img.xz
```

---

## 📚 Summary

**Your complete workflow:**

1. **One-time setup on Build Machine:**
   - Install Docker and dependencies
   - Clone `rpi-image-gen`

2. **For each build:**
   - Copy `ugv-rpi-image/` from Pi to Build Machine
   - Add your local files (`mqtt_bridge/`, etc.) to `layers/50-custom-files/files/`
   - Edit `config.yaml` to define file mappings
   - Build image with `./build.sh`
   - Flash to SD card

3. **Deploy:**
   - Insert SD card into Pi
   - Boot
   - All your files are there!

**No manual configuration on the Pi needed** - everything is baked into the image! 🚀

---

## 🔗 Related Documentation

- **Main RPI Image Guide:** `/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md`
- **Custom Files Quick Start:** `/home/ubuntu/ws/ugv-rpi-image/QUICK_START_CUSTOM_FILES.md`
- **Custom Files Detailed Guide:** `/home/ubuntu/ws/ugv-rpi-image/CUSTOM_FILES_GUIDE.md`
- **Complete Setup Summary:** `/home/ubuntu/COMPLETE_SETUP_SUMMARY.md`
