# 🍎 START HERE - macOS Users

## 🎉 Welcome!

You're about to build a custom Raspberry Pi OS image **on your Mac** with:
- ✅ ROS 2 Jazzy (pre-installed)
- ✅ UGV Workspace (pre-built)
- ✅ **Your MQTT Bridge package** (automatically included)
- ✅ UGV Beast files (launch files, drivers, scripts)
- ✅ Everything ready to use!

**Your configuration is complete and validated!** ✅

---

## 📍 Quick Navigation

### 🏃 I Want to Build Now! (Fastest Path)

👉 **Go to:** [`QUICKSTART_MACOS.md`](./QUICKSTART_MACOS.md)

**What you'll do:**
1. Install Docker Desktop (5 minutes)
2. Clone rpi-image-gen (1 minute)
3. Run build command (2-4 hours)
4. Flash to SD card (5 minutes)

**Total hands-on time:** ~15 minutes  
**Total wait time:** 2-4 hours (can walk away)

---

### 📖 I Want to Understand Everything First

👉 **Go to:** [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md)

**What you'll learn:**
- 3 different build methods (Docker Desktop, VM, Remote Server)
- Complete troubleshooting guide
- Performance comparison
- macOS-specific tips and tricks

---

### 📋 I Just Need Quick Reference

👉 **Go to:** [`MACOS_CHEATSHEET.md`](./MACOS_CHEATSHEET.md)

**What you'll get:**
- One-page command reference
- Copy-paste ready commands
- Quick troubleshooting

---

### 🎨 I Like Visual Guides

👉 **Go to:** [`COMPLETE.md`](./COMPLETE.md)

**What you'll see:**
- Visual diagrams
- File flow charts
- What gets copied where
- Build process visualization

---

## 🍎 Why macOS-Specific Guides?

Building on macOS has some differences from Linux:
- Different disk device naming (`/dev/diskN` vs `/dev/sdX`)
- Docker Desktop instead of native Docker
- Different package manager (Homebrew vs apt)
- macOS-specific permissions and tools

**We've created complete macOS guides** so you don't have to translate Linux commands!

---

## 🚀 Recommended Path for Different Users

### First-Time Builder
1. Read [`QUICKSTART_MACOS.md`](./QUICKSTART_MACOS.md) (5 min read)
2. Follow the 4 steps
3. Come back if you hit issues

### Experienced Developer
1. Skim [`MACOS_CHEATSHEET.md`](./MACOS_CHEATSHEET.md) (2 min)
2. Run the commands
3. Check [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md) for troubleshooting

### Want Best Performance
1. Read [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md) - Option 2 or 3
2. Set up Linux VM or Remote Server
3. Build with better performance

---

## 📦 What's Already Done

✅ **MQTT Bridge Package Copied**
- All Python files (mqtt_bridge_node.py, adapters, plugins)
- 13 files ready to be included

✅ **UGV Beast Files Ready**
- Launch files (master_beast.launch.py)
- Drivers (ugv_integrated_driver.py)
- Scripts (start_ugv.sh, ugv_services_install.sh)

✅ **Configuration Complete**
- Main config.yaml created
- File mappings defined
- Build commands configured

✅ **Validation Passed**
- Ran validation script
- All checks passed
- Ready to build!

---

## 🎯 What Happens When You Build

```
YOUR MAC                    DOCKER BUILD                 RASPBERRY PI
┌──────────┐               ┌─────────────┐              ┌──────────┐
│          │               │             │              │          │
│ Config   │  Build Cmd    │ Ubuntu      │   Flash      │ Boot &   │
│ Files    │  ──────────>  │ + ROS 2     │  ────────>   │ Run      │
│          │               │ + Your      │   SD Card    │          │
│ mqtt_    │               │   Files     │              │ Everything│
│ bridge/  │               │             │              │ Ready!   │
│          │               │ [.img.xz]   │              │          │
└──────────┘               └─────────────┘              └──────────┘
  Already                    2-4 hours                    5 minutes
  on Mac!                    (automated)                  (flash)
```

**Your files are already on your Mac!** No need to copy anything.

---

## ⚡ Quick Start Commands (Copy-Paste)

```bash
# Install Docker Desktop
brew install --cask docker && open -a Docker

# Wait for Docker to start (green icon in menu bar)

# Clone builder
cd ~ && git clone https://github.com/raspberrypi/rpi-image-gen.git

# Build (takes 2-4 hours)
cd ~/rpi-image-gen
sudo ./build.sh /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/config.yaml

# Flash to SD card (easiest way)
brew install --cask raspberry-pi-imager
open -a "Raspberry Pi Imager"
# Then: Choose custom → select ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

---

## 🎓 Build Time Expectations

| Phase | Time | Can Walk Away? |
|-------|------|----------------|
| **Setup** (Docker, clone) | 5-10 min | ❌ |
| **Build** (image creation) | 2-4 hours | ✅ Yes! |
| **Flash** (SD card write) | 5-10 min | ⏳ Monitor |
| **First Boot** | 2 min | ✅ Yes! |

**Total hands-on time:** ~20 minutes  
**Total elapsed time:** ~3-5 hours

---

## 💡 Pro Tips

1. **Start the build before lunch** - come back and it's done!
2. **Use Raspberry Pi Imager** - it's the easiest flashing method
3. **Keep Docker Desktop running** - don't quit it during build
4. **Don't sleep your Mac** - the build might pause
5. **Have 60GB+ free** - the build needs space

---

## 🆘 If You Get Stuck

1. **Check the troubleshooting section** in your chosen guide
2. **Run the validation script:** `./validate-config.sh`
3. **Check Docker is running:** `docker ps`
4. **Verify disk space:** `df -h`

---

## 📚 All Documentation Files

### macOS-Specific (🍎 You are here!)
- [`START_HERE_MACOS.md`](./START_HERE_MACOS.md) - This file (overview)
- [`QUICKSTART_MACOS.md`](./QUICKSTART_MACOS.md) - 4-step quick start
- [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md) - Complete guide
- [`MACOS_CHEATSHEET.md`](./MACOS_CHEATSHEET.md) - Command reference

### General Documentation
- [`README.md`](./README.md) - Project overview
- [`COMPLETE.md`](./COMPLETE.md) - Visual summary
- [`SUMMARY.md`](./SUMMARY.md) - Configuration summary
- [`INDEX.md`](./INDEX.md) - Full documentation index

### Linux (if you have a Linux machine)
- [`QUICKSTART.md`](./QUICKSTART.md) - Linux quick start
- [`BUILD_GUIDE.md`](./BUILD_GUIDE.md) - Linux complete guide

### Configuration Files
- [`config.yaml`](./config.yaml) - Main image config
- [`layers/50-custom-files/config.yaml`](./layers/50-custom-files/config.yaml) - File mappings

### Tools
- [`validate-config.sh`](./validate-config.sh) - Validation script

---

## ✨ Why This Approach?

### Traditional Setup (What You'd Do Without This)
```
❌ Flash base Ubuntu to each Pi
❌ Install ROS 2 manually (60+ minutes)
❌ Configure system (serial, Docker, etc.)
❌ Clone repositories
❌ Build workspace (30-45 minutes)
❌ Copy your files manually
❌ Test and troubleshoot
❌ REPEAT for every Pi!

Time per device: 2-3 hours
Error-prone: Very
Reproducible: No
```

### Custom Image (What You're Building)
```
✅ Build once on Mac (automated)
✅ Flash to SD card (5 minutes)
✅ Boot Pi - everything works!
✅ Flash to 100 Pis - same time!

Time per device: 5 minutes
Error-prone: No
Reproducible: Perfect
```

---

## 🎯 Your Next Step

**Choose your path:**

- 🏃 **Fast:** Go to [`QUICKSTART_MACOS.md`](./QUICKSTART_MACOS.md) and start building
- 📖 **Thorough:** Read [`BUILD_GUIDE_MACOS.md`](./BUILD_GUIDE_MACOS.md) first
- 📋 **Quick Ref:** Check [`MACOS_CHEATSHEET.md`](./MACOS_CHEATSHEET.md)

---

## 🎉 What You'll Have

After flashing and booting:

```bash
# SSH into Pi
ssh ubuntu@<PI_IP>  # Password: ubuntu

# Everything is ready!
cd /home/ubuntu/ws/ugv_ws

# Your MQTT Bridge is here:
ls src/mqtt_bridge/mqtt_bridge/

# Your UGV files are here:
ls src/ugv_main/ugv_bringup/launch/

# Just start it:
export UGV_MODEL=ugv_beast
./start_ugv.sh

# 🎉 System running - no setup needed!
```

---

**Ready to build?** Choose a guide above and let's go! 🚀

---

**Your configuration location:**
```
/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/
```

**Last Updated:** 2026-02-09  
**Platform:** macOS (Intel & Apple Silicon)  
**Status:** ✅ Ready to Build
