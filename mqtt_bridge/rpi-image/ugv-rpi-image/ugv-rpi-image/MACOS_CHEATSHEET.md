# 🍎 macOS Build Cheat Sheet

## Prerequisites
```bash
# Install Docker Desktop
brew install --cask docker
open -a Docker  # Start it, wait for green icon

# Configure: Docker Desktop → Settings → Resources
# CPUs: 4+, Memory: 8GB+, Disk: 60GB+
```

## Build Image
```bash
# Clone builder
cd ~ && git clone https://github.com/raspberrypi/rpi-image-gen.git

# Build (2-4 hours)
cd ~/rpi-image-gen
sudo ./build.sh /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/config.yaml

# Output: ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

## Flash SD Card

### Method 1: Raspberry Pi Imager (Easiest)
```bash
brew install --cask raspberry-pi-imager
open -a "Raspberry Pi Imager"
# Choose custom → select .img.xz → select SD card → Write
```

### Method 2: Command Line
```bash
diskutil list                    # Find SD card (e.g., disk2)
diskutil unmountDisk /dev/diskN  # Replace N with your disk number
cd ~/rpi-image-gen/deploy
unxz ugv-ros2-jazzy-v1.0.0.img.xz
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/rdiskN bs=4m  # Use rdiskN!
diskutil eject /dev/diskN
```

## Boot & Verify
```bash
# Find Pi IP
arp -a | grep -i "b8:27:eb\|dc:a6:32"

# SSH into Pi
ssh ubuntu@<PI_IP>  # Password: ubuntu

# Verify
ls /home/ubuntu/ws/ugv_ws/src/mqtt_bridge/mqtt_bridge/
ls /home/ubuntu/ws/ugv_ws/*.sh

# Start
export UGV_MODEL=ugv_beast
cd /home/ubuntu/ws/ugv_ws && ./start_ugv.sh
```

## Troubleshooting
```bash
# Docker not running?
open -a Docker && sleep 10 && docker ps

# Check SD card
diskutil list | grep "external, physical"

# Unmount stuck disk
diskutil unmountDisk force /dev/diskN
```

## Important Notes
- ✅ Use `/dev/rdiskN` (with 'r') for faster writing
- ✅ Don't sleep Mac during build
- ✅ Keep Docker Desktop running
- ✅ Need 60GB+ free space
- ⏱️ Build takes 2-4 hours

---
**Your config is ready at:**
`/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/`
