# Edge ROS UR7 Setup - Custom Ubuntu 24.04 ROS 2 Jazzy Image

## 📋 Overview

This directory contains a pre-configured Ubuntu 24.04 ARM64 system image for Raspberry Pi with ROS 2 Jazzy Jalisco, specifically configured for UR7e robot control via MQTT Bridge.

**Image File**: `custom-ubuntu-ros2-20251203-065742.img.xz`

### What's Included

- **Ubuntu 24.04.3 LTS (ARM64)** - Optimized for Raspberry Pi 4/5
- **ROS 2 Jazzy Jalisco** - Latest ROS 2 LTS release
- **UR Robot Driver** - Pre-built and configured for UR7e
- **MQTT Bridge** - Remote robot control via MQTT
- **EPick Gripper Support** - Hardware interface and controllers
- **Serial Library** - For gripper communication
- **Pre-configured workspace** - Ready to launch at `~/workspace/ros_ur_driver/`

---

## 🎯 Quick Start

### Requirements

- **Raspberry Pi 4 or 5** (4GB+ RAM recommended)
- **SD Card**: 32GB minimum, 64GB+ recommended
- **Network**: Ethernet connection to UR7e robot
- **Monitor, Keyboard, Mouse** (for initial setup)

### Step 1: Write Image to SD Card

#### Method A: Raspberry Pi Imager (Recommended - Easiest)

1. **Download Raspberry Pi Imager**:
   - Website: https://www.raspberrypi.com/software/
   - Available for Windows, macOS, and Linux

2. **Launch the Imager**:
   ```bash
   # On Linux
   sudo apt install rpi-imager
   rpi-imager
   ```

3. **Configure**:
   - Click **"Choose OS"** → **"Use custom"**
   - Select: `custom-ubuntu-ros2-20251203-065742.img.xz`
   - Click **"Choose Storage"** → Select your SD card
   - Click **"Write"** (No need to extract the .xz file!)

4. **Wait**: Takes 10-20 minutes depending on your SD card speed

5. **Done**: Safely eject the SD card

#### Method B: Command Line (Linux/macOS)

```bash
# 1. Identify your SD card device
lsblk

# 2. Unmount if mounted (replace sdX with your device)
sudo umount /dev/sdX*

# 3. Write the image (replace sdX with your device, e.g., sdb, sdc)
sudo sh -c 'xzcat custom-ubuntu-ros2-20251203-065742.img.xz | dd of=/dev/sdX bs=4M status=progress conv=fsync'

# 4. Wait for completion and sync
sync
```

⚠️ **WARNING**: Double-check the device name! Using the wrong device will erase that disk!

#### Method C: Command Line (Windows)

Use [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) or [Etcher](https://www.balena.io/etcher/).

---

## 🚀 First Boot Setup

### 1. Insert SD Card and Boot

1. Insert the SD card into your Raspberry Pi
2. Connect:
   - HDMI monitor
   - USB keyboard and mouse
   - Ethernet cable (to same network as UR7e robot)
   - Power supply
3. Power on
4. Wait 2-3 minutes for first boot

### 2. Login Credentials

```
Username: edgeros
Password: (same as source system where image was created)
```

### 3. Expand Filesystem (Important!)

If you're using an SD card larger than 32GB, expand the filesystem:

```bash
sudo raspi-config
# Navigate to: 6 Advanced Options → A1 Expand Filesystem
# Select OK → Finish → Reboot
```

### 4. Update System (Recommended)

```bash
sudo apt update
sudo apt upgrade -y
```

### 5. Configure Network

#### Check Current Network

```bash
ip addr show
ping 192.168.1.102  # Replace with your UR7e robot IP
```

#### Configure Static IP (Optional)

```bash
# Edit netplan configuration
sudo nano /etc/netplan/50-cloud-init.yaml
```

Example configuration for static IP:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

Apply changes:

```bash
sudo netplan apply
```

### 6. Change Password (Recommended)

```bash
passwd
# Enter current password, then new password twice
```

---

## 🔧 ROS 2 Workspace Setup

### Verify ROS 2 Installation

```bash
# Source ROS 2
source /opt/ros/jazzy/setup.bash

# Check version
ros2 --version
# Expected: ros2 cli version: 0.32.1

# Check available packages
ros2 pkg list | grep ur
```

### Rebuild Workspace (Recommended on First Boot)

```bash
cd ~/workspace/ros_ur_driver

# Source ROS 2
source /opt/ros/jazzy/setup.bash

# Clean build (optional but recommended)
rm -rf build/ install/ log/

# Build all packages
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# Source the workspace
source install/setup.bash
```

### Auto-Source ROS 2 (Optional but Convenient)

Add these lines to your `~/.bashrc`:

```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "source ~/workspace/ros_ur_driver/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

---

## 🤖 Launching the UR7e Robot Control

### Option 1: Direct UR Robot Driver

**Prerequisites**:
- UR7e robot powered on
- Robot in **Remote Control** mode
- Network connection verified

**Launch Command**:

```bash
# Source environment
source /opt/ros/jazzy/setup.bash
source ~/workspace/ros_ur_driver/install/setup.bash

# Launch robot driver
ros2 launch ur_robot_driver ur_control.launch.py \
    ur_type:=ur7e \
    robot_ip:=192.168.1.102 \
    use_fake_hardware:=false
```

**Verify Connection**:

```bash
# In a new terminal, check joint states
source ~/workspace/ros_ur_driver/install/setup.bash
ros2 topic echo /joint_states

# List all topics
ros2 topic list

# Check running nodes
ros2 node list
```

### Option 2: MQTT Bridge for Remote Control

**Configuration**:

Edit MQTT bridge config:

```bash
nano ~/workspace/ros_ur_driver/src/mqtt_bridge/config/bridge_params.yaml
```

Update broker settings:

```yaml
mqtt_bridge:
  ros__parameters:
    broker:
      host: "your-mqtt-broker-hostname"
      port: 1883
      username: "your-username"  # Optional
      password: "your-password"  # Optional
```

**Launch MQTT Bridge**:

```bash
# Source environment
source /opt/ros/jazzy/setup.bash
source ~/workspace/ros_ur_driver/install/setup.bash

# Launch bridge
ros2 launch mqtt_bridge bridge_launch.py
```

**Test MQTT Control**:

Publish to MQTT topic to control the robot:

```bash
# Example: Move joint
mosquitto_pub -h localhost -t "/ur7e/joint_trajectory_controller/joint_trajectory" \
  -m '{"joint_names": ["shoulder_pan_joint", "shoulder_lift_joint", "elbow_joint", "wrist_1_joint", "wrist_2_joint", "wrist_3_joint"], "points": [{"positions": [0.0, -1.57, 1.57, -1.57, -1.57, 0.0], "time_from_start": {"sec": 5, "nanosec": 0}}]}'
```

### Option 3: EPick Gripper Control

**Gripper Configuration** (Must be done on UR teach pendant):

1. On UR teach pendant: **Installation → URCaps → EPick**
2. Configure Modbus:
   - Settings → I/O → Modbus → Add Device
   - Name: `EPick_Gripper`
   - Slave ID: `9`
   - Interface: `Tool`
   - Baud rate: `115200`
3. Add signal:
   - Name: `epick_cmd`
   - Type: **OUTPUT REGISTER**
   - Address: `1000`
   - Data type: `UINT16`

**Launch Gripper Control**:

```bash
# Source environment
source /opt/ros/jazzy/setup.bash
source ~/workspace/ros_ur_driver/install/setup.bash

# Launch gripper controllers
ros2 launch epick_controllers epick_controller.launch.py

# Test grip command
ros2 service call /grip_cmd std_srvs/srv/SetBool "{data: true}"

# Test release command
ros2 service call /grip_cmd std_srvs/srv/SetBool "{data: false}"
```

---

## 📁 Important Directory Structure

```
/home/edgeros/
├── workspace/
│   └── ros_ur_driver/                    # Main ROS 2 workspace
│       ├── src/
│       │   ├── mqtt_bridge/              # MQTT bridge package
│       │   │   ├── config/               # Configuration files
│       │   │   │   └── bridge_params.yaml
│       │   │   └── mqtt_bridge/
│       │   │       └── mqtt_bridge_node.py
│       │   ├── ros2_epick_gripper/       # EPick gripper packages
│       │   │   ├── epick_driver/
│       │   │   ├── epick_controllers/
│       │   │   ├── epick_description/
│       │   │   └── epick_msgs/
│       │   └── Universal_Robots_ROS2_Driver/
│       ├── build/                        # Build artifacts
│       ├── install/                      # Installed packages
│       └── log/                          # Build logs
│
├── cyberwave/                            # CyberWave project directory
│   └── cyberwave-edges/
│       └── cyberwave-ros2/
│           └── mqtt_bridge/
│               └── edge-ros-ur7-setup/   # This directory!
│
/etc/netplan/                             # Network configuration
/opt/ros/jazzy/                           # ROS 2 installation
/root/IMAGE_INFO.txt                      # Image creation details
```

---

## 🔍 Useful ROS 2 Commands

### Diagnostics

```bash
# List all ROS 2 topics
ros2 topic list

# Show topic information
ros2 topic info /joint_states

# Echo topic data
ros2 topic echo /joint_states

# List all nodes
ros2 node list

# Show node information
ros2 node info /ur_control_node

# List all services
ros2 service list

# List all actions
ros2 action list
```

### Robot Control

```bash
# Check joint states
ros2 topic echo /joint_states --once

# Publish joint trajectory (example)
ros2 topic pub /joint_trajectory_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "..."

# Call gripper service
ros2 service call /grip_cmd std_srvs/srv/SetBool "{data: true}"

# Send gripper action
ros2 action send_goal /epick_gripper_controller/gripper_cmd control_msgs/action/GripperCommand "{command: {position: 0.0, max_effort: 100.0}}"
```

---

## 🆘 Troubleshooting

### Issue: "ros2: command not found"

**Solution**:
```bash
source /opt/ros/jazzy/setup.bash
source ~/workspace/ros_ur_driver/install/setup.bash
```

### Issue: Network connection to robot fails

**Diagnosis**:
```bash
# Check if robot is reachable
ping 192.168.100.44

# Check network interface
ip addr show

# Check routing
ip route
```

**Solutions**:
1. Verify Ethernet cable is connected
2. Check robot IP address matches configuration
3. Ensure robot is in **Remote Control** mode
4. Verify netplan configuration: `sudo netplan apply`

### Issue: Build fails with missing dependencies

**Solution**:
```bash
cd ~/workspace/ros_ur_driver
source /opt/ros/jazzy/setup.bash

# Install dependencies
rosdep install --from-paths src --ignore-src -r -y

# Clean and rebuild
rm -rf build/ install/ log/
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
```

### Issue: MQTT bridge won't connect

**Diagnosis**:
```bash
# Check MQTT broker connectivity
ping your-mqtt-broker-hostname

# Test MQTT connection
mosquitto_sub -h your-mqtt-broker-hostname -t "#" -v
```

## 🔒 Security Recommendations

### Change Default Credentials

```bash
# Change user password
passwd

# Change root password
sudo passwd root
```

### Update Regularly

```bash
# Create update script
echo '#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
' > ~/update_system.sh

chmod +x ~/update_system.sh

# Run weekly
./update_system.sh
```

---

## 📊 System Information

### Image Details

- **OS**: Ubuntu 24.04.3 LTS (ARM64)
- **Kernel**: Linux 6.8.0 (Raspberry Pi optimized)
- **ROS Version**: ROS 2 Jazzy Jalisco
- **Python**: 3.12
- **Created**: December 3, 2025
- **Size**: ~8GB compressed, ~32GB uncompressed

### Pre-installed Packages

**ROS 2 Packages**:
- `ros-jazzy-desktop` - Full ROS 2 desktop installation
- `ros-jazzy-ur-robot-driver` - UR robot driver
- `ros-jazzy-moveit` - Motion planning framework
- Custom packages: `mqtt_bridge`, `epick_driver`, `epick_controllers`

**System Packages**:
- `build-essential` - Compilation tools
- `git` - Version control
- `python3-pip` - Python package manager
- `mosquitto-clients` - MQTT tools
- `net-tools` - Network utilities
- `htop` - System monitor

### Workspace Packages

```bash
# List all packages in workspace
source ~/workspace/ros_ur_driver/install/setup.bash
ros2 pkg list | grep -E "(ur_|epick|mqtt)"
```

Expected packages:
- `ur_robot_driver`
- `ur_controllers`
- `ur_description`
- `mqtt_bridge`
- `epick_driver`
- `epick_controllers`
- `epick_description`
- `epick_msgs`
- `serial`

---

### Creating Systemd Services

Example: Auto-start MQTT bridge on boot

```bash
# Create service file
sudo nano /etc/systemd/system/mqtt-bridge.service
```

```ini
[Unit]
Description=ROS 2 MQTT Bridge
After=network.target

[Service]
Type=simple
User=edgeros
Environment="HOME=/home/edgeros"
ExecStart=/bin/bash -c "source /opt/ros/jazzy/setup.bash && source /home/edgeros/workspace/ros_ur_driver/install/setup.bash && ros2 launch mqtt_bridge bridge_launch.py"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable mqtt-bridge.service
sudo systemctl start mqtt-bridge.service

# Check status
sudo systemctl status mqtt-bridge.service
```

---

##  Additional Resources

### Documentation

- [ROS 2 Jazzy Documentation](https://docs.ros.org/en/jazzy/)
- [UR ROS 2 Driver](https://github.com/UniversalRobots/Universal_Robots_ROS2_Driver)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
- [Ubuntu ARM Documentation](https://ubuntu.com/download/raspberry-pi)

### Community Support

- **ROS Discourse**: https://discourse.ros.org/
- **UR+ Platform**: https://www.universal-robots.com/plus/
- **Raspberry Pi Forums**: https://forums.raspberrypi.com/

### Video Tutorials

- ROS 2 Basics: https://www.youtube.com/c/TheConstruct
- UR Robot Programming: https://academy.universal-robots.com/

---

##  Safety and Legal

### Robot Safety

- **Always follow UR safety guidelines**
- Test in a safe, isolated environment before production use
- Implement proper emergency stop mechanisms
- Maintain safety distances per ISO 10218
- Perform risk assessments before deployment
- Ensure proper training for all operators

### Software License

This image contains open-source software:
- Ubuntu: GPLv2
- ROS 2: Apache License 2.0
- UR ROS Driver: Apache License 2.0

Custom packages (MQTT Bridge, EPick Driver) may have separate licenses. Check individual package LICENSE files.

### Warranty Disclaimer

This custom image is provided "AS IS" without warranty of any kind. Use at your own risk. Always test thoroughly before production deployment.

---

## 📝 Changelog

### Version: 20251203-065742

**Initial Release**:
- Ubuntu 24.04.3 LTS ARM64
- ROS 2 Jazzy Jalisco
- UR Robot Driver pre-configured for UR7e
- MQTT Bridge with single-joint SDK support
- EPick Gripper hardware interface and controllers
- Serial library for RS-485 communication
- Pre-built workspace ready to launch

---

## 🙏 Credits

- **Universal Robots** - UR ROS 2 Driver
- **Open Robotics** - ROS 2 framework
- **Canonical** - Ubuntu for Raspberry Pi
- **Raspberry Pi Foundation** - Hardware platform
- **ROS Community** - Tools and libraries

---
*Last Updated: December 3, 2025*

