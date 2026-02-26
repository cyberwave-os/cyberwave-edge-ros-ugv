# Troubleshooting Guide

## Common Issues and Solutions

### Installation Issues

#### ROS 2 Not Found
**Error**: `ROS 2 Humble not found at /opt/ros/humble`

**Solution**:
```bash
# Install ROS 2 Humble
# Follow the official guide: https://docs.ros.org/en/humble/Installation.html
```

#### Permission Denied
**Error**: `Permission denied` when running scripts

**Solution**:
```bash
# Make scripts executable
chmod +x scripts/install.sh
chmod +x scripts/uninstall.sh

# Run with sudo
sudo ./scripts/install.sh
```

### Connection Issues

#### Bridge Not Connecting to MQTT
**Symptoms**: Bridge starts but doesn't connect to Cyberwave

**Solution**:
```bash
# 1. Check environment variables
cat /opt/cyberwave-edge-ros/.env

# 2. Verify credentials
echo $CYBERWAVE_TOKEN
echo $CYBERWAVE_TWIN_UUID

# 3. Test MQTT connection
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t '#' -v

# 4. Check logs with debug level
sudo journalctl -u cyberwave-edge-ros -f
# Or edit .env to set LOG_LEVEL=DEBUG
```

#### Digital Twin Not Updating
**Symptoms**: Bridge is running but digital twin doesn't update

**Solution**:
```bash
# 1. Check if rate limiting is too aggressive
ros2 param get /mqtt_bridge_node ros2mqtt_rate_limit

# 2. Temporarily disable rate limiting
export MQTT_PUBLISH_RATE_LIMIT=0
ros2 run mqtt_bridge mqtt_bridge_node

# 3. Check if ROS topics are publishing
ros2 topic list
ros2 topic hz /joint_states

# 4. Monitor MQTT traffic
mosquitto_sub -h mqtt.cyberwave.com -t 'cyberwave/+/+/update' -v
```

### ROS 2 Issues

#### Topics Not Publishing
**Symptoms**: ROS topics show 0 Hz

**Solution**:
```bash
# Check if robot driver is running
ros2 node list

# Restart robot driver
sudo systemctl restart your-robot-driver

# Check topic info
ros2 topic info /joint_states
ros2 topic echo /joint_states
```

#### Build Errors
**Error**: `colcon build` fails

**Solution**:
```bash
# Clean build artifacts
rm -rf build/ install/ log/

# Install dependencies
rosdep update
rosdep install --from-paths . --ignore-src -r -y

# Build with verbose output
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Debug
```

### Service Issues

#### Service Won't Start
**Symptoms**: `systemctl start cyberwave-edge-ros` fails

**Solution**:
```bash
# Check service status
sudo systemctl status cyberwave-edge-ros

# Check service file
cat /etc/systemd/system/cyberwave-edge-ros.service

# Reload daemon
sudo systemctl daemon-reload

# Try starting manually
cd /opt/cyberwave-edge-ros
source /opt/ros/humble/setup.bash
source install/setup.bash
ros2 run mqtt_bridge mqtt_bridge_node
```

#### Service Crashes on Startup
**Symptoms**: Service starts but immediately fails

**Solution**:
```bash
# Check logs
sudo journalctl -u cyberwave-edge-ros -n 100

# Common causes:
# 1. Missing .env file
sudo ls -la /opt/cyberwave-edge-ros/.env

# 2. Invalid credentials
sudo nano /opt/cyberwave-edge-ros/.env

# 3. Missing dependencies
source /opt/cyberwave-edge-ros/venv/bin/activate
pip install -r /opt/cyberwave-edge-ros/requirements.txt
```

### Performance Issues

#### Too Much Network Traffic
**Symptoms**: High bandwidth usage

**Solution**:
```bash
# Increase rate limit interval (lower frequency)
# Edit .env file
MQTT_PUBLISH_RATE_LIMIT=2.0  # 0.5 Hz instead of 1 Hz

# Restart service
sudo systemctl restart cyberwave-edge-ros
```

#### High CPU Usage
**Symptoms**: Bridge uses excessive CPU

**Solution**:
```bash
# Check if rate limiting is disabled
ros2 param get /mqtt_bridge_node ros2mqtt_rate_limit

# Enable rate limiting
ros2 param set /mqtt_bridge_node ros2mqtt_rate_limit 1.0

# Check for topic loops
ros2 topic list
ros2 topic hz /cmd_vel  # Should only publish when commanded
```

### Debugging Commands

#### Enable Debug Logging
```bash
# Method 1: Environment variable
export LOG_LEVEL=DEBUG

# Method 2: Launch parameter
ros2 launch mqtt_bridge mqtt_bridge.launch.py log_level:=debug

# Method 3: Edit .env
sudo nano /opt/cyberwave-edge-ros/.env
# Set: LOG_LEVEL=DEBUG
```

#### Monitor All Topics
```bash
# ROS topics
ros2 topic list
ros2 topic hz /joint_states
ros2 topic echo /joint_states

# MQTT topics
mosquitto_sub -h mqtt.cyberwave.com -t '#' -v | ts '[%H:%M:%S]'
```

#### Check Node Parameters
```bash
# List all parameters
ros2 param list /mqtt_bridge_node

# Get specific parameter
ros2 param get /mqtt_bridge_node robot_id
ros2 param get /mqtt_bridge_node ros2mqtt_rate_limit

# Set parameter
ros2 param set /mqtt_bridge_node ros2mqtt_rate_limit 1.0
```

## Getting Help

If you're still experiencing issues:

1. **Check logs**: `sudo journalctl -u cyberwave-edge-ros -f`
2. **Enable debug mode**: Set `LOG_LEVEL=DEBUG` in `.env`
3. **Review configuration**: Verify all settings in `.env` and `config/params.yaml`
4. **Test manually**: Run the bridge outside of systemd to see detailed output
5. **Create an issue**: https://github.com/cyberwave-os/cyberwave-edge-ros/issues

Include the following in your issue:
- Output of `ros2 topic list`
- Output of `systemctl status cyberwave-edge-ros`
- Relevant logs from `journalctl`
- Your `.env` configuration (redact sensitive tokens)
- Robot platform and ROS 2 version
