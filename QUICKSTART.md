# Quick Start Guide

Get up and running with Cyberwave Edge ROS2 in minutes!

## Prerequisites Checklist

Before you begin, make sure you have:

- [ ] Ubuntu 20.04+ (or compatible Linux distribution)
- [ ] ROS 2 Humble installed
- [ ] Python 3.9 or higher
- [ ] Cyberwave account with API token
- [ ] Digital twin UUID from Cyberwave dashboard
- [ ] ROS 2 compatible robot

## 5-Minute Setup

### Step 1: Clone and Enter Directory (30 seconds)

```bash
git clone https://github.com/cyberwave-os/cyberwave-edge-ros.git
cd cyberwave-edge-ros
```

### Step 2: Install Dependencies (2 minutes)

```bash
# Install ROS 2 dependencies
rosdep install --from-paths . --ignore-src -r -y

# Install Python dependencies
pip install -r requirements.txt
```

### Step 3: Configure Credentials (1 minute)

```bash
# Copy example configuration
cp .env.example .env

# Edit with your credentials
nano .env
```

Add your credentials:
```bash
CYBERWAVE_TOKEN=your_api_token_here
CYBERWAVE_TWIN_UUID=your_twin_uuid_here
ROBOT_ID=default  # or robot_arm_v1, robot_ugv_beast_v1
```

### Step 4: Build and Run (1.5 minutes)

```bash
# Source ROS 2
source /opt/ros/humble/setup.bash

# Build workspace
colcon build --symlink-install

# Source workspace
source install/setup.bash

# Run the bridge
ros2 run mqtt_bridge mqtt_bridge_node
```

### Step 5: Verify (30 seconds)

Check that everything is working:

```bash
# In another terminal, check ROS topics
ros2 topic list

# Should see topics like:
# /joint_states
# /odom
# /cmd_vel
```

## Production Installation

For production deployment with auto-start:

```bash
sudo ./scripts/install.sh
```

Then configure and start:

```bash
# Edit configuration
sudo nano /opt/cyberwave-edge-ros/.env

# Start service
sudo systemctl start cyberwave-edge-ros

# Check status
sudo systemctl status cyberwave-edge-ros

# View logs
sudo journalctl -u cyberwave-edge-ros -f
```

## Robot-Specific Setup

### For Robotic Arms (UR series, etc.)

```bash
# In .env file
ROBOT_ID=robot_arm_v1

# Edit mapping file
nano mqtt_bridge/config/mappings/robot_arm_v1.yaml
# Update twin_uuid
```

### For UGV Robots

```bash
# In .env file
ROBOT_ID=robot_ugv_beast_v1

# Edit mapping file
nano mqtt_bridge/config/mappings/robot_ugv_beast_v1.yaml
# Update twin_uuid and wheel parameters
```

### For Custom Robots

1. Copy default mapping:
   ```bash
   cp mqtt_bridge/config/mappings/default.yaml \
      mqtt_bridge/config/mappings/my_robot.yaml
   ```

2. Edit the file:
   ```bash
   nano mqtt_bridge/config/mappings/my_robot.yaml
   ```

3. Set in `.env`:
   ```bash
   ROBOT_ID=my_robot
   ```

## Getting Your Credentials

### API Token

1. Go to [cyberwave.com](https://cyberwave.com)
2. Log in to your account
3. Navigate to **Settings** → **API Tokens**
4. Click **Create New Token**
5. Copy the token

### Twin UUID

1. Log in to Cyberwave dashboard
2. Navigate to your project
3. Click **Digital Twins**
4. Create a new twin or select existing one
5. Copy the UUID from the twin details

## Troubleshooting Quick Fixes

### Bridge won't connect

```bash
# Check credentials
cat .env | grep CYBERWAVE_TOKEN

# Test MQTT connection
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -t '#' -v
```

### No ROS topics

```bash
# Check if robot driver is running
ros2 node list

# Check topic publishing rate
ros2 topic hz /joint_states
```

### Service won't start

```bash
# Check logs
sudo journalctl -u cyberwave-edge-ros -n 50

# Run manually for debugging
cd /opt/cyberwave-edge-ros
source /opt/ros/humble/setup.bash
source install/setup.bash
ros2 run mqtt_bridge mqtt_bridge_node
```

## What's Next?

- **Configure rate limiting**: Edit `MQTT_PUBLISH_RATE_LIMIT` in `.env`
- **Set up camera streaming**: See WebRTC documentation
- **Create custom plugins**: See Plugin Development guide
- **Monitor performance**: Use ROS 2 tools (`ros2 topic hz`, etc.)

## Common Commands

```bash
# Start/stop service
sudo systemctl start cyberwave-edge-ros
sudo systemctl stop cyberwave-edge-ros
sudo systemctl restart cyberwave-edge-ros

# Check service status
sudo systemctl status cyberwave-edge-ros

# View logs
sudo journalctl -u cyberwave-edge-ros -f

# Run manually (development)
ros2 run mqtt_bridge mqtt_bridge_node

# Check ROS topics
ros2 topic list
ros2 topic echo /joint_states

# Check bridge parameters
ros2 param list /mqtt_bridge_node
ros2 param get /mqtt_bridge_node ros2mqtt_rate_limit
```

## Need Help?

- **Documentation**: See `docs/` directory
- **Troubleshooting**: Read `docs/TROUBLESHOOTING.md`
- **Configuration**: Read `docs/ROBOT_CONFIGURATION.md`
- **Issues**: https://github.com/cyberwave-os/cyberwave-edge-ros/issues

## Architecture Overview

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│             │ ROS2    │              │  MQTT   │             │
│ Robot       ├────────►│ MQTT Bridge  ├────────►│ Cyberwave   │
│ Hardware    │ 100 Hz  │ (Rate Limit) │  1 Hz   │ Cloud       │
│             │◄────────┤              │◄────────┤             │
└─────────────┘         └──────────────┘         └─────────────┘
                               │
                               │ Config
                               ▼
                        ┌──────────────┐
                        │ Mapping File │
                        │  .yaml       │
                        └──────────────┘
```

## Key Features

✅ **Bidirectional**: ROS 2 ↔ MQTT in both directions  
✅ **Rate Limiting**: 99% bandwidth reduction (100 Hz → 1 Hz)  
✅ **Plug & Play**: Works with multiple robot types  
✅ **Secure**: Source type filtering prevents accidental commands  
✅ **Flexible**: Configurable via YAML and environment variables  
✅ **Production Ready**: Systemd service with auto-restart  

Happy robotics! 🤖
