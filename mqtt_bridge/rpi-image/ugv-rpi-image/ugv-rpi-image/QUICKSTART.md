# 🚀 Quick Start: Building Your UGV Raspberry Pi Image

## ✅ Configuration Complete!

Your UGV Raspberry Pi image configuration is **ready to build**. All files have been properly set up:

- ✅ MQTT Bridge package (complete)
- ✅ UGV Beast launch files
- ✅ Startup scripts
- ✅ Configuration files
- ✅ Build scripts
- ✅ All documentation

## 📍 What You Have

**Image Configuration Location:**
```
/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/
```

**Contents:**
```
ugv-rpi-image/
├── config.yaml                    # Main image configuration
├── BUILD_GUIDE.md                 # Complete build guide (READ THIS!)
├── validate-config.sh             # Validation script (already passed ✓)
├── layers/
│   └── 50-custom-files/
│       ├── config.yaml            # File mappings
│       └── files/
│           ├── mqtt_bridge/       # Your MQTT Bridge package
│           └── ugv_beast/         # UGV Beast files
└── scripts/                       # Build scripts
```

## 🎯 Building the Image (4 Simple Steps)

### Step 1: Set Up Build Machine

Your Build Machine should be a powerful PC/laptop (not the Raspberry Pi).

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Log out and back in

# Install dependencies
sudo apt update
sudo apt install -y git wget qemu-user-static binfmt-support

# Clone rpi-image-gen
cd ~
git clone https://github.com/raspberrypi/rpi-image-gen.git
```

### Step 2: Copy Configuration to Build Machine

```bash
# On Build Machine, create workspace
mkdir -p ~/ugv-build

# From your Mac (where the files are now):
scp -r /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/ \
  <BUILD_MACHINE_USER>@<BUILD_MACHINE_IP>:~/ugv-build/

# Or if building on the same machine:
cp -r /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/rpi-image/ugv-rpi-image/ugv-rpi-image/ \
  ~/ugv-build/
```

### Step 3: Build the Image

```bash
# On Build Machine
cd ~/rpi-image-gen

# Build (takes 2-4 hours)
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# Wait for completion...
# Output will be in: ~/rpi-image-gen/deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

### Step 4: Flash to SD Card

**Option A - Raspberry Pi Imager (Easiest):**
1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Choose OS → **Use custom** → Select `ugv-ros2-jazzy-v1.0.0.img.xz`
3. Choose your SD card
4. Click **Write**

**Option B - Command Line:**
```bash
cd ~/rpi-image-gen/deploy

# Find SD card device
lsblk  # or diskutil list on macOS

# Flash (⚠️ DOUBLE-CHECK THE DEVICE!)
sudo dd if=ugv-ros2-jazzy-v1.0.0.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

## 🎉 What's Included in Your Image

When you boot the Raspberry Pi from this image, it will have:

### System Configuration
- ✅ Ubuntu 24.04 ARM64
- ✅ ROS 2 Jazzy (pre-installed)
- ✅ Docker (pre-configured)
- ✅ Serial port configured
- ✅ Boot settings optimized
- ✅ All udev rules in place

### UGV Workspace
- ✅ Pre-built ROS 2 workspace at `/home/ubuntu/ws/ugv_ws/`
- ✅ All UGV packages built and ready
- ✅ Environment auto-sourced in .bashrc

### MQTT Bridge Package
- ✅ Complete package at `/home/ubuntu/ws/ugv_ws/src/mqtt_bridge/`
- ✅ All plugins included
- ✅ Pre-built and ready to use

### UGV Beast Files
- ✅ `master_beast.launch.py` launch file
- ✅ `ugv_integrated_driver.py` driver
- ✅ `start_ugv.sh` startup script
- ✅ `ugv_services_install.sh` service installer

### Ready to Use!
Just boot, SSH in, and run:
```bash
cd /home/ubuntu/ws/ugv_ws
./start_ugv.sh
```

## 🔍 Verification After First Boot

```bash
# 1. SSH into Pi
ssh ubuntu@<PI_IP>
# Password: ubuntu

# 2. Check MQTT Bridge is present
ls /home/ubuntu/ws/ugv_ws/src/mqtt_bridge/mqtt_bridge/

# 3. Check UGV files
ls /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/

# 4. Test ROS 2
source /opt/ros/jazzy/setup.bash
source /home/ubuntu/ws/ugv_ws/install/setup.bash
ros2 pkg list | grep mqtt

# 5. Start the system
export UGV_MODEL=ugv_beast
./start_ugv.sh
```

## 📚 Documentation

For detailed information, check:

1. **`BUILD_GUIDE.md`** - Complete build guide with troubleshooting
2. **`BUILD_MACHINE_WORKFLOW.md`** - Step-by-step workflow
3. **`CUSTOM_FILES_GUIDE.md`** - How custom files work
4. **`layers/50-custom-files/config.yaml`** - File mapping configuration

## ⚙️ Customization

To add more files or make changes:

1. Add files to `layers/50-custom-files/files/`
2. Update `layers/50-custom-files/config.yaml` with new mappings
3. Rebuild the image
4. Flash to SD cards

## 🔄 Configuration Summary

**Main Configuration:** `config.yaml`
```yaml
name: ugv-ros2-jazzy
version: 1.0.0
size: 16G
user: ubuntu / ubuntu
hostname: ugv-robot
```

**Custom Files Layer:** `layers/50-custom-files/config.yaml`
- 5 UGV Beast files → `/home/ubuntu/ws/ugv_ws/`
- 13 MQTT Bridge files → `/home/ubuntu/ws/ugv_ws/src/mqtt_bridge/`
- All files will be automatically copied and built

## 🎯 Next Actions

1. ✅ **Configuration validated** (already done - ran `validate-config.sh`)
2. 🔄 **Set up Build Machine** (install Docker + rpi-image-gen)
3. 🔄 **Copy configuration** to Build Machine
4. 🔄 **Build image** (2-4 hours)
5. 🔄 **Flash to SD card** (5 minutes)
6. 🔄 **Test on Raspberry Pi** (verify everything works)
7. 🔄 **Deploy to fleet** (flash to additional devices)

## 💡 Pro Tips

- **First build takes longest** (downloads base image, installs packages)
- **Subsequent builds are faster** (uses cache)
- **Keep the .img.xz file** for easy re-flashing
- **Tag versions** (v1.0.0, v1.1.0) for rollback capability
- **Test on one Pi first** before deploying to fleet

## 🆘 Getting Help

If you encounter issues:

1. Check `BUILD_GUIDE.md` troubleshooting section
2. Run `validate-config.sh` to verify configuration
3. Check build logs: `~/rpi-image-gen/build.log`
4. Verify all files exist in `layers/50-custom-files/files/`

## ✨ What Makes This Special

Traditional setup:
- Flash base image → Install ROS 2 → Clone repos → Build workspace → Copy files
- **Takes 2-3 hours per device**
- **Error-prone** (manual steps)
- **Not reproducible**

Your custom image:
- Flash → Boot → Everything ready!
- **Takes 5 minutes per device**
- **Reproducible** (identical every time)
- **Version controlled** (track changes in Git)

---

**🎉 Congratulations!** Your UGV Raspberry Pi image configuration is complete and validated. Just build, flash, and deploy! 🚀

All your MQTT Bridge code and UGV configurations are ready to be baked into the image.
