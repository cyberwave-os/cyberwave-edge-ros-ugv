# 🍎 Quick Start: Building UGV Image on macOS

## ✅ Your Configuration is Ready!

Everything is already set up on your Mac at:
```
/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/
```

---

## 🚀 Build in 4 Simple Steps (macOS)

### Step 1: Install Docker Desktop

```bash
# Option A: Download installer
open https://www.docker.com/products/docker-desktop/

# Option B: Install via Homebrew
brew install --cask docker

# Start Docker Desktop from Applications
# Wait for green icon in menu bar
```

**Configure Docker Desktop:**
1. Open Docker Desktop
2. Settings → Resources
3. Set: CPUs: 4+, Memory: 8GB+, Disk: 60GB+
4. Apply & Restart

### Step 2: Clone rpi-image-gen

```bash
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
```

### Step 3: Build the Image

```bash
cd ~/rpi-image-gen

# Build (takes 2-4 hours)
sudo ./build.sh /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/config.yaml

# Output will be in:
# ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

**☕ Take a break!** This takes 2-4 hours. You can close the terminal and check back later.

### Step 4: Flash to SD Card

**Option A: Raspberry Pi Imager (Easiest)**

```bash
# Install Raspberry Pi Imager
brew install --cask raspberry-pi-imager

# Open it
open -a "Raspberry Pi Imager"

# Then:
# 1. Choose OS → Use custom
# 2. Select: ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
# 3. Choose Storage → Your SD card
# 4. Click Write
```

**Option B: Command Line**

```bash
# Find SD card
diskutil list

# Unmount it (replace diskN with your disk number, e.g., disk2)
diskutil unmountDisk /dev/diskN

# Extract image
cd ~/rpi-image-gen/deploy
unxz ugv-ros2-jazzy-v1.0.0.img.xz

# Flash (use rdiskN with 'r' for faster writing!)
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/rdiskN bs=4m

# Eject
diskutil eject /dev/diskN
```

---

## 🎉 Done!

Insert SD card into Raspberry Pi, boot, and SSH in:

```bash
# Find Pi's IP (check your router or use arp)
arp -a | grep -i "b8:27:eb\|dc:a6:32"

# SSH into Pi
ssh ubuntu@<PI_IP>
# Password: ubuntu

# Start the UGV system
export UGV_MODEL=ugv_beast
cd /home/ubuntu/ws/ugv_ws
./start_ugv.sh
```

Everything is ready - no setup needed! 🚀

---

## 🔧 Troubleshooting

### Docker not starting?
```bash
# Make sure Docker Desktop is running
open -a Docker
# Wait for green light in menu bar
```

### Build too slow?
Consider using a Linux VM or remote server (see BUILD_GUIDE_MACOS.md)

### SD card not detected?
```bash
# List all disks
diskutil list

# Your SD card is usually /dev/disk2 or /dev/disk4
# Check the SIZE column to confirm
```

---

## 📚 More Information

- **Full macOS Guide:** [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md)
  - 3 build methods (Docker Desktop, VM, Remote Server)
  - Complete troubleshooting
  - Performance tips

- **Visual Summary:** [`COMPLETE.md`](./COMPLETE.md)
  - See what's included
  - Visual diagrams

- **Configuration Details:** [`SUMMARY.md`](./SUMMARY.md)
  - File mappings
  - What gets copied where

---

## 💡 Pro Tips

1. **Use `/dev/rdiskN` (with 'r')** for faster SD card writing
2. **Close other apps** during build for better performance
3. **Don't sleep your Mac** during the build
4. **Keep Docker Desktop running** throughout the build

---

**Ready in 4 steps!** Your MQTT Bridge and UGV files will be automatically included in the image. 🎉
