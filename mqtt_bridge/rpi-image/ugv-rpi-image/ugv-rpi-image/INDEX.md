# UGV RPI Image Build - Documentation Index

## 📖 Quick Navigation

This directory contains everything you need to build a custom Raspberry Pi OS image for your UGV with ROS 2 Jazzy and your custom files (like `mqtt_bridge`).

---

## 🚀 START HERE

### For Build Machine Users (Recommended Starting Point)

**You want to build the image on your PC with your local `mqtt_bridge` folder?**

👉 **Read this first:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md)
- Complete step-by-step workflow
- Explains how to copy `ugv-rpi-image` from Pi to your PC
- Shows how to add your local files
- Full build and flash instructions

👉 **Visual guide:** [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md)
- Diagrams showing file flow
- Visual representation of the build process
- Quick command reference

👉 **Command checklist:** [`build-commands.sh`](./build-commands.sh)
- Copy-paste ready commands
- Complete workflow from start to finish
- Run to see all commands you need

```bash
# Show the complete command workflow
bash /home/ubuntu/ws/ugv-rpi-image/build-commands.sh
```

---

## 📚 Documentation by Topic

### Adding Custom Files

**You want to include custom files (launch files, configs, scripts) in your image?**

1. **Quick start:** [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md)
   - TL;DR version
   - Your exact use case (copying files like Docker COPY)
   - Simple 3-step process

2. **Detailed guide:** [`CUSTOM_FILES_GUIDE.md`](./CUSTOM_FILES_GUIDE.md)
   - Comprehensive reference
   - All patterns and examples
   - Advanced features (templates, permissions, etc.)

3. **Layer documentation:** [`layers/50-custom-files/README.md`](./layers/50-custom-files/README.md)
   - Layer-specific documentation
   - File structure
   - How to add more files

### Build Machine Workflow

**You want to build on your PC (not the Raspberry Pi)?**

1. **Complete workflow:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md)
   - Full end-to-end process
   - Prerequisites and setup
   - Build, flash, and verify

2. **Visual guide:** [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md)
   - Diagrams and flow charts
   - File mapping visualization
   - Quick reference

3. **Command checklist:** [`build-commands.sh`](./build-commands.sh)
   - All commands in order
   - Copy-paste ready
   - Verification steps

### General RPI Image Generation

**You want to understand rpi-image-gen in depth?**

- **Main guide:** [`/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md`](/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md)
  - rpi-image-gen overview
  - Layer architecture
  - Configuration reference
  - All YAML templates

### System Configuration

**You want to know what system configurations are applied?**

- **Pi setup guide:** [`/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md`](/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md)
  - Boot configuration (config.txt, cmdline.txt)
  - Serial port setup
  - Docker configuration
  - Network and hardware settings

### ROS 2 Workspace

**You want to understand the ROS 2 workspace setup?**

- **Build summary:** [`/home/ubuntu/ws/ugv_ws/BUILD_SUMMARY.md`](/home/ubuntu/ws/ugv_ws/BUILD_SUMMARY.md)
  - What packages were built
  - Source code fixes applied
  - Known issues and workarounds

- **Workspace guide:** [`/home/ubuntu/ROS2_WORKSPACE_GUIDE.md`](/home/ubuntu/ROS2_WORKSPACE_GUIDE.md)
  - Environment sourcing
  - Package not found troubleshooting
  - Quick setup helpers

### Complete Reference

**You want a summary of everything that's been set up?**

- **Complete summary:** [`/home/ubuntu/COMPLETE_SETUP_SUMMARY.md`](/home/ubuntu/COMPLETE_SETUP_SUMMARY.md)
  - All completed tasks
  - All documentation created
  - Current system status
  - Next steps

---

## 📁 Directory Structure

```
/home/ubuntu/ws/ugv-rpi-image/
├── README.md                          ← You were here (overview)
├── INDEX.md                           ← You are here (navigation)
├── BUILD_MACHINE_WORKFLOW.md          ← Complete build workflow
├── BUILD_MACHINE_VISUAL_GUIDE.md      ← Visual diagrams
├── QUICK_START_CUSTOM_FILES.md        ← Quick custom files guide
├── CUSTOM_FILES_GUIDE.md              ← Detailed custom files guide
├── build-commands.sh                  ← Command checklist
├── config.yaml                        ← Main image configuration (create if needed)
│
├── layers/                            ← Image build layers
│   ├── 00-base/                       ← Base system packages
│   ├── 10-ros2-jazzy/                 ← ROS 2 Jazzy installation
│   ├── 20-ugv-system/                 ← UGV system configuration
│   │   └── files/                     ← Boot configs, udev rules, etc.
│   ├── 30-ugv-workspace/              ← ROS 2 workspace build
│   │   └── files/
│   │       └── setup_ros.sh           ← Quick workspace sourcing
│   ├── 40-ugv-apps/                   ← UGV applications
│   └── 50-custom-files/               ← YOUR CUSTOM FILES GO HERE
│       ├── config.yaml                ← File mappings (like Docker COPY)
│       ├── README.md                  ← Layer documentation
│       ├── validate.sh                ← Validation script
│       ├── setup-helper.sh            ← Status checker
│       └── files/                     ← SOURCE FILES
│           ├── ugv_beast/             ← UGV Beast custom files
│           │   ├── launch/
│           │   ├── ugv_bringup/
│           │   ├── setup.py
│           │   └── *.sh
│           └── mqtt_bridge/           ← ADD YOUR mqtt_bridge HERE
│               ├── config/
│               ├── scripts/
│               └── systemd/
│
└── scripts/                           ← Build scripts
    ├── apply-fixes.sh                 ← Source code fixes for ROS 2 Jazzy
    ├── build-workspace.sh             ← Workspace build script
    └── install-python.sh              ← Python dependencies
```

---

## 🎯 Common Tasks - Where to Look

### Task: "I want to build the image on my PC with my local mqtt_bridge folder"

1. **Read:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md)
2. **Quick reference:** [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md)
3. **Commands:** Run `bash build-commands.sh` to see all commands

**Quick answer:**
```bash
# 1. Copy from Pi to PC
scp -r ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image ~/ugv-build/

# 2. Add your mqtt_bridge
cp -r ~/projects/mqtt_bridge ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files/

# 3. Edit config to map files
nano ~/ugv-build/ugv-rpi-image/layers/50-custom-files/config.yaml

# 4. Build image
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml
```

---

### Task: "How do I add custom files to the image?"

1. **Quick start:** [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md)
2. **Detailed guide:** [`CUSTOM_FILES_GUIDE.md`](./CUSTOM_FILES_GUIDE.md)
3. **Layer README:** [`layers/50-custom-files/README.md`](./layers/50-custom-files/README.md)

**Quick answer:**
- Put source files in: `layers/50-custom-files/files/`
- Define mappings in: `layers/50-custom-files/config.yaml`
- Build image → files automatically copied!

---

### Task: "What's the complete workflow from start to finish?"

1. **Full workflow:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) (most comprehensive)
2. **Command checklist:** `bash build-commands.sh` (all commands)
3. **Visual guide:** [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md) (diagrams)

---

### Task: "I want to understand how custom files work"

1. **Start here:** [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md)
2. **Deep dive:** [`CUSTOM_FILES_GUIDE.md`](./CUSTOM_FILES_GUIDE.md)
3. **Check status:** `bash layers/50-custom-files/setup-helper.sh`

---

### Task: "What system configurations are included?"

- **Pi configuration:** [`/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md`](/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md)
- **Boot config files:** `layers/20-ugv-system/files/`

---

### Task: "How do I verify everything is set up correctly?"

```bash
# Check custom files status
bash layers/50-custom-files/setup-helper.sh

# Validate files
bash layers/50-custom-files/validate.sh

# View all commands
bash build-commands.sh
```

---

### Task: "I want to see all the documentation"

**Overview and summaries:**
- [`README.md`](./README.md) - Quick start overview
- [`INDEX.md`](./INDEX.md) - This file (navigation)
- [`/home/ubuntu/COMPLETE_SETUP_SUMMARY.md`](/home/ubuntu/COMPLETE_SETUP_SUMMARY.md) - Complete system summary

**Build machine workflow:**
- [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) - Complete workflow
- [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md) - Visual guide
- [`build-commands.sh`](./build-commands.sh) - Command checklist

**Custom files:**
- [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md) - Quick start
- [`CUSTOM_FILES_GUIDE.md`](./CUSTOM_FILES_GUIDE.md) - Complete guide
- [`layers/50-custom-files/README.md`](./layers/50-custom-files/README.md) - Layer docs

**System and ROS:**
- [`/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md`](/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md) - rpi-image-gen guide
- [`/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md`](/home/ubuntu/ws/UGV_RASPBERRY_PI_SETUP.md) - System config
- [`/home/ubuntu/ws/ugv_ws/BUILD_SUMMARY.md`](/home/ubuntu/ws/ugv_ws/BUILD_SUMMARY.md) - Workspace build
- [`/home/ubuntu/ROS2_WORKSPACE_GUIDE.md`](/home/ubuntu/ROS2_WORKSPACE_GUIDE.md) - ROS 2 troubleshooting

---

## 🔗 Quick Links

### Helper Scripts

```bash
# Show build machine workflow commands
bash /home/ubuntu/ws/ugv-rpi-image/build-commands.sh

# Check custom files status
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/setup-helper.sh

# Validate custom files
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/validate.sh
```

### Key Configuration Files

```bash
# Main image configuration
cat /home/ubuntu/ws/ugv-rpi-image/config.yaml

# Custom files layer configuration
cat /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/config.yaml

# Boot configuration
cat /home/ubuntu/ws/ugv-rpi-image/layers/20-ugv-system/files/config.txt
```

---

## 🎓 Learning Path

### If you're new to rpi-image-gen:

1. **Start:** [`README.md`](./README.md) - Overview
2. **Learn:** [`/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md`](/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md) - Concepts
3. **Practice:** [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md) - Simple example
4. **Build:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) - Complete workflow

### If you just want to build the image:

1. **Commands:** `bash build-commands.sh` - See all commands
2. **Workflow:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) - Follow along
3. **Visual:** [`BUILD_MACHINE_VISUAL_GUIDE.md`](./BUILD_MACHINE_VISUAL_GUIDE.md) - Understand flow

### If you need to add custom files:

1. **Quick:** [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md) - Fast method
2. **Details:** [`CUSTOM_FILES_GUIDE.md`](./CUSTOM_FILES_GUIDE.md) - All options
3. **Layer:** [`layers/50-custom-files/README.md`](./layers/50-custom-files/README.md) - Layer docs

---

## 💡 FAQ

**Q: What do I need on my Build Machine?**
A: Docker, git, qemu-user-static. See [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) Step 0.

**Q: How long does the build take?**
A: 2-4 hours depending on your PC specs.

**Q: Do I need to copy ugv-rpi-image to my Build Machine?**
A: Yes! Use `scp` or `rsync`. See [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md) Step 1.

**Q: Where do I put my mqtt_bridge folder?**
A: In `layers/50-custom-files/files/mqtt_bridge/`. See [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md).

**Q: How do I know if my files are included?**
A: Run `bash layers/50-custom-files/setup-helper.sh` to check status.

**Q: Can I test files locally before building the full image?**
A: Yes! See "Testing Before Building Full Image" in [`QUICK_START_CUSTOM_FILES.md`](./QUICK_START_CUSTOM_FILES.md).

**Q: What if the build fails?**
A: Check troubleshooting section in [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md).

---

## 📞 Getting Help

If you're stuck, check these in order:

1. **This INDEX** - Find the right document for your task
2. **README.md** - Quick overview and next steps
3. **Specific guides** - Detailed documentation for your task
4. **Helper scripts** - Run validation and status checks
5. **Complete summary** - [`/home/ubuntu/COMPLETE_SETUP_SUMMARY.md`](/home/ubuntu/COMPLETE_SETUP_SUMMARY.md)

---

## ✅ Next Steps

**Ready to build? Here's what to do:**

1. **Read the workflow:** [`BUILD_MACHINE_WORKFLOW.md`](./BUILD_MACHINE_WORKFLOW.md)
2. **See the commands:** `bash build-commands.sh`
3. **Copy files:** Transfer `ugv-rpi-image` to your Build Machine
4. **Add custom files:** Put `mqtt_bridge` in `layers/50-custom-files/files/`
5. **Build:** `sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml`
6. **Flash:** Write image to SD card
7. **Boot:** Insert SD and power on!

---

**Last Updated:** 2026-02-09  
**Version:** 1.0.0  
**Maintainer:** UGV Team
