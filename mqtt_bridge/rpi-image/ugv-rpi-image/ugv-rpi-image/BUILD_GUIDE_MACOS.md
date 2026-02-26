# UGV Raspberry Pi Image Build Guide - macOS Edition

This guide will help you build a custom Raspberry Pi OS image with ROS 2 Jazzy, UGV packages, and the MQTT Bridge **on your Mac**.

## 📦 What's Been Customized

Your image configuration is ready with:

✅ **MQTT Bridge Package (Complete)**
- `mqtt_bridge_node.py`, `cyberwave_mqtt_adapter.py`, `command_handler.py`
- All plugins (odometry, navigation, camera, command handler)

✅ **UGV Beast Files**
- `master_beast.launch.py`, `ugv_integrated_driver.py`
- `start_ugv.sh`, `ugv_services_install.sh`

✅ **Configuration Files**
- Main `config.yaml` ready
- Custom files layer configured
- All file mappings defined

---

## 🍎 Building on macOS - Three Options

### Option 1: Docker Desktop for Mac (Recommended - Easiest)

**Pros:** Works directly on your Mac, no remote server needed  
**Cons:** Requires Docker Desktop, may have performance limitations  
**Best for:** Quick builds, testing, small-scale deployment

### Option 2: Linux VM on Mac (Good Alternative)

**Pros:** Full Linux environment, better performance than Docker Desktop  
**Cons:** Requires VM setup and management  
**Best for:** Regular builds, better performance

### Option 3: Remote Linux Server (Professional Setup)

**Pros:** Best performance, can run builds in background  
**Cons:** Requires separate Linux machine or cloud instance  
**Best for:** Production, fleet deployment, CI/CD

---

## 🚀 Option 1: Using Docker Desktop for Mac

### Step 1: Install Prerequisites

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop for Mac
# Download from: https://www.docker.com/products/docker-desktop/
# Or install via Homebrew:
brew install --cask docker

# Start Docker Desktop from Applications
# Wait for it to start (Docker icon in menu bar should be green)

# Verify Docker is running
docker --version
docker ps

# Install git (if not already installed)
brew install git
```

### Step 2: Clone rpi-image-gen

```bash
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
cd rpi-image-gen
```

### Step 3: Your Configuration is Already on Your Mac!

Your image configuration is at:
```
/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/
```

No need to copy - it's already here! Just create a symlink for convenience:

```bash
# Create a convenient symlink
mkdir -p ~/ugv-build
ln -s /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image ~/ugv-build/ugv-rpi-image

# Verify it works
ls -la ~/ugv-build/ugv-rpi-image/config.yaml
```

### Step 4: Configure Docker Desktop for Mac

Docker Desktop needs enough resources for the build:

1. Open **Docker Desktop**
2. Go to **Settings** (⚙️ gear icon)
3. Click **Resources**
4. Allocate:
   - **CPUs:** At least 4 (more is better)
   - **Memory:** At least 8GB (16GB recommended)
   - **Disk:** At least 60GB free
5. Click **Apply & Restart**

### Step 5: Build the Image

```bash
cd ~/rpi-image-gen

# Build the image (2-4 hours)
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# Or use the direct path:
sudo ./build.sh /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/config.yaml

# The build will:
# 1. Download Ubuntu 24.04 ARM64 (~2GB)
# 2. Install ROS 2 Jazzy
# 3. Build UGV workspace
# 4. Copy your MQTT Bridge files
# 5. Create final image

# Output will be in:
# ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

### Step 6: Flash to SD Card (macOS)

**Option A: Raspberry Pi Imager (Easiest)**

```bash
# Download Raspberry Pi Imager
open https://www.raspberrypi.com/software/

# Or install via Homebrew
brew install --cask raspberry-pi-imager

# Then:
# 1. Open Raspberry Pi Imager
# 2. Choose OS → Use custom
# 3. Select: ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
# 4. Choose Storage → Your SD card
# 5. Click Write
```

**Option B: Command Line (dd)**

```bash
# 1. Insert SD card into your Mac

# 2. Find the SD card device
diskutil list
# Look for your SD card (usually /dev/disk2 or /dev/disk4)
# Check the SIZE to make sure it's the right one!

# 3. Unmount the SD card (replace diskN with your disk number)
diskutil unmountDisk /dev/diskN

# 4. Extract the image (if needed)
cd ~/rpi-image-gen/deploy
unxz ugv-ros2-jazzy-v1.0.0.img.xz

# 5. Flash to SD card
# IMPORTANT: Use /dev/rdiskN (with 'r') for faster writing!
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/rdiskN bs=4m status=progress

# This will take about 5-10 minutes

# 6. Eject the SD card
diskutil eject /dev/diskN
```

**Option C: Balena Etcher**

```bash
# Install Balena Etcher
brew install --cask balenaetcher

# Or download from: https://etcher.balena.io/

# Then:
# 1. Open Balena Etcher
# 2. Flash from file → Select ugv-ros2-jazzy-v1.0.0.img.xz
# 3. Select target → Your SD card
# 4. Flash!
```

---

## 🖥️ Option 2: Using Linux VM on Mac

### Step 1: Install VM Software

**Option A: UTM (Free, Apple Silicon friendly)**

```bash
# For Apple Silicon Macs (M1/M2/M3)
brew install --cask utm

# Download Ubuntu 24.04 ARM64 Server
open https://ubuntu.com/download/server/arm

# Create new VM in UTM:
# - Type: Linux
# - ISO: Ubuntu 24.04 ARM64
# - RAM: 8GB+
# - CPUs: 4+
# - Disk: 80GB+
```

**Option B: VMware Fusion Player (Free for personal use)**

```bash
# Download VMware Fusion Player
open https://www.vmware.com/products/fusion.html

# Download Ubuntu 24.04 AMD64 Desktop
open https://ubuntu.com/download/desktop

# Create new VM with:
# - RAM: 8GB+
# - CPUs: 4+
# - Disk: 80GB+
```

**Option C: VirtualBox (Free)**

```bash
# Install VirtualBox
brew install --cask virtualbox

# Download Ubuntu 24.04 AMD64 Desktop
open https://ubuntu.com/download/desktop

# Create new VM with:
# - RAM: 8GB+
# - CPUs: 4+
# - Disk: 80GB+
```

### Step 2: Set Up Ubuntu VM

```bash
# After installing Ubuntu in the VM:

# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect

# 2. Install dependencies
sudo apt update
sudo apt install -y git wget qemu-user-static binfmt-support

# 3. Clone rpi-image-gen
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
```

### Step 3: Copy Configuration from Mac to VM

```bash
# On your Mac, copy the configuration to the VM
# (Replace USER@VM_IP with your VM's username and IP)

scp -r /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/ \
  USER@VM_IP:~/ugv-build/

# Or use VM's shared folder feature:
# - UTM: Set up shared directory in VM settings
# - VMware: Enable shared folders
# - VirtualBox: Set up shared folders
```

### Step 4: Build in VM

```bash
# In the Ubuntu VM:
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# Wait 2-4 hours...

# Copy the image back to Mac
scp deploy/ugv-ros2-jazzy-v1.0.0.img.xz USER@MAC_IP:~/Downloads/
```

### Step 5: Flash on Mac

Use the same flashing instructions as Option 1 above.

---

## 🌐 Option 3: Using Remote Linux Server

### Step 1: Set Up Remote Server

**Option A: Cloud Provider (AWS, DigitalOcean, etc.)**

```bash
# Example: DigitalOcean Droplet
# - Choose Ubuntu 24.04
# - At least 8GB RAM
# - 80GB+ disk space
# - 4+ vCPUs

# SSH into your server
ssh root@YOUR_SERVER_IP
```

**Option B: Your Own Linux Machine**

```bash
# SSH into your Linux machine
ssh your-username@YOUR_LINUX_IP
```

### Step 2: Install Dependencies on Server

```bash
# On the Linux server:

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install dependencies
sudo apt update
sudo apt install -y git wget qemu-user-static binfmt-support

# Clone rpi-image-gen
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
```

### Step 3: Copy Configuration from Mac to Server

```bash
# On your Mac, copy the configuration
scp -r /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/ \
  your-username@YOUR_SERVER_IP:~/ugv-build/

# Or use rsync for better performance:
rsync -avz --progress \
  /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/ \
  your-username@YOUR_SERVER_IP:~/ugv-build/ugv-rpi-image/
```

### Step 4: Build on Remote Server

```bash
# SSH into the server
ssh your-username@YOUR_SERVER_IP

# Build the image
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# You can disconnect and let it run in background:
# Use tmux or screen:
tmux new -s build
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml
# Press Ctrl+B, then D to detach

# To reattach later:
tmux attach -t build
```

### Step 5: Download Image to Mac

```bash
# On your Mac, download the built image
scp your-username@YOUR_SERVER_IP:~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz ~/Downloads/

# Or use rsync for resumable downloads:
rsync -avz --progress \
  your-username@YOUR_SERVER_IP:~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz \
  ~/Downloads/
```

### Step 6: Flash on Mac

Use the same flashing instructions as Option 1 above.

---

## ✅ Verification After First Boot

```bash
# 1. Find your Raspberry Pi's IP
# Check your router, or use:
arp -a | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01"

# 2. SSH into the Pi
ssh ubuntu@<RASPBERRY_PI_IP>
# Password: ubuntu

# 3. Verify files are present
ls -la /home/ubuntu/ws/ugv_ws/src/mqtt_bridge/mqtt_bridge/
# Should show: mqtt_bridge_node.py, cyberwave_mqtt_adapter.py, etc.

ls -la /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
# Should show: master_beast.launch.py

ls -la /home/ubuntu/ws/ugv_ws/*.sh
# Should show: start_ugv.sh, ugv_services_install.sh

# 4. Test ROS 2
source /opt/ros/jazzy/setup.bash
source /home/ubuntu/ws/ugv_ws/install/setup.bash

ros2 pkg list | grep mqtt
# Should show: mqtt_bridge

ros2 pkg list | grep ugv
# Should show: ugv_bringup, ugv_driver, etc.

# 5. Start the system
export UGV_MODEL=ugv_beast
cd /home/ubuntu/ws/ugv_ws
./start_ugv.sh
```

---

## 🔧 Troubleshooting macOS-Specific Issues

### Issue: "Cannot connect to Docker daemon"

**Solution:**
```bash
# Make sure Docker Desktop is running
open -a Docker

# Wait for the Docker icon in menu bar to show a green light

# Test Docker
docker ps
```

### Issue: "Not enough memory" during build

**Solution:**
```bash
# Increase Docker Desktop memory:
# Docker Desktop → Settings → Resources → Memory
# Set to at least 8GB (16GB recommended)
# Click Apply & Restart
```

### Issue: "dd: /dev/diskN: Resource busy"

**Solution:**
```bash
# Unmount all partitions on the SD card
diskutil unmountDisk /dev/diskN

# Then try dd again
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/rdiskN bs=4m
```

### Issue: "Operation not permitted" when using dd

**Solution:**
```bash
# macOS Catalina+ requires Full Disk Access for Terminal
# System Settings → Privacy & Security → Full Disk Access
# Add Terminal.app (or your terminal emulator)

# Or use Raspberry Pi Imager instead (easier)
```

### Issue: Build is very slow

**Possible causes:**
1. **Docker Desktop performance:** Use Option 2 (VM) or Option 3 (remote) instead
2. **Not enough CPUs:** Increase in Docker Desktop settings
3. **Disk I/O:** Make sure Docker Desktop is using the right disk location

**Solution:**
```bash
# Check Docker settings:
# Docker Desktop → Settings → Resources
# - CPUs: 4+ (more is better)
# - Memory: 16GB recommended
# - Disk: 80GB+ free

# For best performance, use Option 2 or 3
```

### Issue: "qemu-user-static not found"

**Solution:**
```bash
# This is typically not needed on Mac with Docker Desktop
# Docker Desktop handles ARM emulation automatically

# If building in a VM, install in the VM:
sudo apt install -y qemu-user-static binfmt-support
```

---

## 💡 macOS-Specific Tips

### Tip 1: Use Fast SD Card Writing

```bash
# Always use /dev/rdiskN (with 'r') instead of /dev/diskN
# This bypasses disk caching and is much faster!

# Slow (buffered):
sudo dd if=image.img of=/dev/disk2 bs=4m

# Fast (raw):
sudo dd if=image.img of=/dev/rdisk2 bs=4m
```

### Tip 2: Monitor Build Progress

```bash
# In another terminal, watch Docker:
docker ps
docker stats

# Check disk usage:
df -h

# Monitor system resources:
top
# Or install htop:
brew install htop
htop
```

### Tip 3: Use Shared Folders for VM

If using a VM, set up shared folders to avoid scp:

**UTM:**
```bash
# UTM → Select VM → Edit → Sharing
# Add your Mac folder as shared directory
# In VM: mount shared folder
```

**VMware Fusion:**
```bash
# Settings → Sharing → Enable Shared Folders
# Add Mac folder
# In VM: /mnt/hgfs/SharedFolder/
```

**VirtualBox:**
```bash
# Settings → Shared Folders → Add
# In VM: sudo mount -t vboxsf SharedFolder /mnt/shared
```

### Tip 4: Automate with a Script

Create a build script on your Mac:

```bash
#!/bin/bash
# build-ugv-image.sh

set -e

echo "🚀 Building UGV Raspberry Pi Image on Mac"

# Check Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Paths
CONFIG_PATH="/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image"
RPI_IMAGE_GEN="$HOME/rpi-image-gen"

# Clone rpi-image-gen if not exists
if [ ! -d "$RPI_IMAGE_GEN" ]; then
    echo "📥 Cloning rpi-image-gen..."
    git clone https://github.com/raspberrypi/rpi-image-gen.git "$RPI_IMAGE_GEN"
fi

cd "$RPI_IMAGE_GEN"

echo "🔨 Starting build (this will take 2-4 hours)..."
sudo ./build.sh "$CONFIG_PATH/config.yaml"

echo "✅ Build complete!"
echo "📦 Image: $RPI_IMAGE_GEN/deploy/ugv-ros2-jazzy-v1.0.0.img.xz"
echo ""
echo "Next: Flash to SD card using Raspberry Pi Imager"
```

Save it and run:
```bash
chmod +x build-ugv-image.sh
./build-ugv-image.sh
```

---

## 📊 Performance Comparison

| Method | Build Time | Setup Difficulty | Ongoing Maintenance |
|--------|-----------|------------------|-------------------|
| **Docker Desktop** | 3-5 hours | Easy | Low |
| **Linux VM** | 2-4 hours | Medium | Medium |
| **Remote Server** | 2-3 hours | Medium | Low |

**Recommendation:**
- **First-time/Testing:** Use Docker Desktop (Option 1)
- **Regular builds:** Use Linux VM (Option 2)
- **Production/Fleet:** Use Remote Server (Option 3)

---

## 🎯 Complete macOS Workflow

### Quick Reference

```bash
# OPTION 1: Docker Desktop (Easiest)
# ───────────────────────────────────
# 1. Install Docker Desktop
brew install --cask docker

# 2. Clone rpi-image-gen
cd ~ && git clone https://github.com/raspberrypi/rpi-image-gen.git

# 3. Build (your config is already on Mac!)
cd ~/rpi-image-gen
sudo ./build.sh /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/config.yaml

# 4. Flash to SD card
diskutil list  # Find SD card
diskutil unmountDisk /dev/diskN
cd deploy && unxz ugv-ros2-jazzy-v1.0.0.img.xz
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

---

## 📚 Additional Resources

- **Docker Desktop for Mac:** https://www.docker.com/products/docker-desktop/
- **UTM (VM for Apple Silicon):** https://mac.getutm.app/
- **Raspberry Pi Imager:** https://www.raspberrypi.com/software/
- **Balena Etcher:** https://etcher.balena.io/
- **rpi-image-gen:** https://github.com/raspberrypi/rpi-image-gen

---

## ✨ Summary

**Your UGV image configuration is ready to build on macOS!**

**Easiest path:**
1. Install Docker Desktop
2. Run the build command
3. Flash with Raspberry Pi Imager
4. Boot and enjoy!

All your MQTT Bridge code and UGV configurations will be automatically included. No manual setup required on the Raspberry Pi! 🚀

---

**Last Updated:** 2026-02-09  
**Platform:** macOS (Ventura, Sonoma, Sequoia)  
**Tested on:** Apple Silicon (M1/M2/M3) and Intel Macs
