# Cyberwave Edge ROS2

[![License: Apache-2.0](https://img.shields.io/github/license/cyberwave-os/cyberwave-edge-ros)](https://github.com/cyberwave-os/cyberwave-edge-ros/blob/main/LICENSE)
[![ROS2](https://img.shields.io/badge/ROS2-Humble-blue.svg)](https://docs.ros.org/en/humble/)
[![GitHub stars](https://img.shields.io/github/stars/cyberwave-os/cyberwave-edge-ros)](https://github.com/cyberwave-os/cyberwave-edge-ros/stargazers)
[![GitHub contributors](https://img.shields.io/github/contributors/cyberwave-os/cyberwave-edge-ros)](https://github.com/cyberwave-os/cyberwave-edge-ros/graphs/contributors)
[![GitHub issues](https://img.shields.io/github/issues/cyberwave-os/cyberwave-edge-ros)](https://github.com/cyberwave-os/cyberwave-edge-ros/issues)

Simple, open-source ROS2 MQTT bridge to integrate robots and sensors to Cyberwave, enabling real-time synchronization between physical robots and cloud-based digital twins.

## Features

✅ **Implemented:**

- Bidirectional communication: ROS 2 ↔ MQTT
- Auto-start on device boot and connect to MQTT
- Automatic reconnection with exponential backoff
- Status reporting to Cyberwave backend
- Command handling via MQTT topics
- WebRTC video streaming from ROS cameras
- Rate limiting with intelligent upstream traffic control (100 Hz → 1 Hz)
- Joint state mapping and transformation
- Configurable logging and error handling
- Source type filtering (prevents accidental commands from editor/sim modes)
- Internal odometry calculation for robots without native odometry
- Navigation Stack (Nav2) integration
- Pluggable command registry for robot-specific hardware

🚧 **Coming Soon:**

- Multi-robot coordination
- Advanced sensor fusion
- Dynamic reconfiguration
- Enhanced diagnostics and monitoring

## Requirements

- Ubuntu 20.04+ (or any Linux with systemd)
- ROS 2 Humble or higher
- Python 3.9 or higher
- Cyberwave account and API token
- Robot with ROS 2 interface

## Getting Started

### Prerequisites

Before you begin, ensure you have the following:

1. **ROS 2 Humble or higher** installed on your system
   ```bash
   ros2 --version
   ```

2. **Cyberwave Account**: Sign up at [cyberwave.com](https://cyberwave.com) to obtain:
   - API Token (from Settings → API Tokens)
   - Twin UUID (create a digital twin and copy its UUID)

3. **Hardware**: ROS 2 compatible robot or sensor platform

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/cyberwave-os/cyberwave-edge-ros.git
   cd cyberwave-edge-ros
   ```

2. **Install dependencies**
   ```bash
   # Install ROS 2 dependencies
   rosdep install --from-paths . --ignore-src -r -y
   
   # Install Python dependencies
   pip install -r requirements.txt
   ```

3. **Configure your environment**
   ```bash
   cp .env.example .env
   nano .env  # Edit with your Cyberwave credentials
   ```

4. **Build the workspace**
   ```bash
   source /opt/ros/humble/setup.bash
   colcon build
   source install/setup.bash
   ```

5. **Run the bridge**
   ```bash
   ros2 run mqtt_bridge mqtt_bridge_node
   ```

That's it! Your ROS 2 robot should now be connected to Cyberwave.

## Installation

### 1. Docker (recommended)

The Docker image bundles ROS 2 Humble, the UGV Beast workspace, and the MQTT bridge.

```bash
# Build the image (~7 GB, first build takes 10-15 min)
docker build -t cyberwaveos/edge-ros-ugv:latest .

# Run with full hardware access (serial, camera, audio)
docker run -dit \
  --name ugv_beast \
  --privileged \
  --net=host \
  -v /dev:/dev \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -e DISPLAY="${DISPLAY}" \
  cyberwaveos/edge-ros-ugv:latest

# SSH into the container (password: ws)
ssh root@localhost -p 23

# Inside the container — start everything
./start_ugv.sh
```

To run only the MQTT bridge (no UGV hardware):

```bash
docker run -dit --name mqtt_bridge --net=host \
  cyberwaveos/edge-ros-ugv:latest \
  bash -c "source /opt/ros/humble/setup.bash && \
           source /home/ws/ugv_ws/install/setup.bash && \
           ros2 run mqtt_bridge mqtt_bridge_node \
             --ros-args -p robot_id:=robot_ugv_beast_v1"
```

### 2. Development Installation (no Docker)

For testing and development directly on the host:

```bash
# Clone the repository
git clone https://github.com/cyberwave-os/cyberwave-edge-ros.git
cd cyberwave-edge-ros

# Install dependencies
rosdep install --from-paths . --ignore-src -r -y
pip install -r requirements.txt

# Build the workspace
source /opt/ros/humble/setup.bash
colcon build
source install/setup.bash

# Copy the example configuration
cp .env.example .env

# Edit the configuration with your credentials
nano .env
```

### 3. Production Installation (Ubuntu/Linux, systemd)

For production deployment as a systemd service:

```bash
# Run the installation script (requires sudo)
sudo ./scripts/install.sh
```

This will:

- Create a dedicated `cyberwave` user
- Install the package to `/opt/cyberwave-edge-ros`
- Set up systemd service for auto-start on boot
- Configure log rotation
- Build the ROS 2 workspace

After installation:

```bash
# Edit the configuration
sudo nano /opt/cyberwave-edge-ros/.env

# Start the service
sudo systemctl start cyberwave-edge-ros

# Enable auto-start on boot (already done by install.sh)
sudo systemctl enable cyberwave-edge-ros

# Check status
sudo systemctl status cyberwave-edge-ros

# View logs
sudo journalctl -u cyberwave-edge-ros -f
```

## Configuration

Create a `.env` file in the installation directory with the following variables:

```bash
# Required
CYBERWAVE_TOKEN=your_api_token_here
CYBERWAVE_TWIN_UUID=your_twin_uuid_here

# Optional
CYBERWAVE_BASE_URL=https://api.cyberwave.com
CYBERWAVE_EDGE_UUID=edge-device-001

# MQTT Configuration
CYBERWAVE_MQTT_BROKER=mqtt.cyberwave.com
CYBERWAVE_MQTT_PORT=1883
CYBERWAVE_MQTT_USERNAME=mqttcyb
CYBERWAVE_MQTT_PASSWORD=mqttcyb231

# Robot Configuration
ROBOT_ID=robot_arm_v1  # Options: robot_arm_v1, robot_ugv_beast_v1, default

# Rate Limiting (Hz)
MQTT_PUBLISH_RATE_LIMIT=1.0  # 1 Hz (once per second)

# Logging
LOG_LEVEL=INFO
```

### Getting Your Credentials

1. **API Token**: Log in to your Cyberwave instance → Settings → API Tokens
2. **Twin UUID**: Create a digital twin in your project and copy its UUID

## Usage

### Running Manually

For development and testing:

```bash
# Source ROS 2
source /opt/ros/humble/setup.bash
source install/setup.bash

# Run the bridge
ros2 run mqtt_bridge mqtt_bridge_node

# Or with parameters
ros2 run mqtt_bridge mqtt_bridge_node --ros-args -p robot_id:=robot_ugv_beast_v1
```

### Running as a Service

For production use with auto-start:

```bash
# Start/stop the service
sudo systemctl start cyberwave-edge-ros
sudo systemctl stop cyberwave-edge-ros

# Restart the service
sudo systemctl restart cyberwave-edge-ros

# View status
sudo systemctl status cyberwave-edge-ros

# View real-time logs
sudo journalctl -u cyberwave-edge-ros -f
```

## Architecture

The ROS 2 MQTT bridge:

1. **Connects to Cyberwave** using the Python SDK
2. **Establishes MQTT connection** for real-time communication
3. **Subscribes to ROS 2 topics**: `/joint_states`, `/odom`, `/cmd_vel`, etc.
4. **Publishes to MQTT topics**: `cyberwave/joint/{twin_uuid}/update`, `cyberwave/pose/{twin_uuid}/update`
5. **Subscribes to MQTT command topics**: `cyberwave/device/{device_id}/commands/#`
6. **Handles commands** via pluggable command handlers
7. **Streams video** via WebRTC from ROS camera topics
8. **Applies rate limiting** to optimize bandwidth (100 Hz → 1 Hz)

### MQTT Topics

**Subscribed Topics (ROS 2 → MQTT):**

- `/joint_states` - Robot joint positions and velocities
- `/odom` - Robot odometry and pose
- `/camera/image_raw` - Camera images for WebRTC streaming

**Published Topics (MQTT → ROS 2):**

- `/cmd_vel` - Velocity commands for robot movement
- Custom command topics based on robot configuration

**MQTT Command Topics:**

- `cyberwave/device/{device_id}/commands/move` - Movement commands
- `cyberwave/device/{device_id}/commands/actuate` - Actuator commands
- `cyberwave/device/{device_id}/commands/config` - Configuration updates

### Rate Limiting

The bridge implements intelligent rate limiting to reduce bandwidth by 99%:

```
Robot ROS Topics (100 Hz)
      ↓
Rate Limiter (1.0 second threshold)
      ↓ (filters 99% of messages)
MQTT Broker (1 Hz)
      ↓
Digital Twin Frontend (smooth visualization)
```

**Default: 1 Hz** (optimal for cloud monitoring)

Configure via `MQTT_PUBLISH_RATE_LIMIT` environment variable.

### Source Type Filtering

**Downstream Filtering (MQTT → ROS)**:
- ✅ Processes: Only messages with `source_type: "tele"` (teleoperation mode)
- ❌ Ignores: Messages from `"edit"`, `"sim"`, or `"edge"` modes

**Purpose**: Prevents accidental commands from editor or simulator from reaching physical robots.

## Robot Configuration

### Creating a Robot Mapping

Create a mapping file in `mqtt_bridge/config/mappings/{robot_id}.yaml`:

```yaml
version: 1
robot_id: "my_robot_v1"
metadata:
  twin_uuid: "your-twin-uuid-here"

joints:
  - ros_name: "shoulder_joint"
    mqtt_name: "shoulder_joint"
    transform: {scale: 1.0, offset: 0.0}

capabilities:
  upstream_mode: "joint"  # Options: joint, pose, both
```

### Available Robot Configurations

- **`robot_arm_v1`**: For robotic arms (e.g., UR robots)
- **`robot_ugv_beast_v1`**: For UGV platforms with wheels
- **`default`**: Generic configuration

## Running Tests

### Docker Smoke Test (Hardware-in-the-Loop)

The smoke test verifies the full ROS 2 graph starts correctly inside the Docker
image by emulating the UGV Beast's ESP32 slave controller over a virtual serial
port.  This catches launch file errors, missing packages, serial protocol
regressions, and topic wiring issues **before** deploying to the physical robot.

**What it does:**

1. Creates a virtual serial port pair with `socat`
2. Runs `mock_esp32.py` — a Python emulator that speaks the same JSON-over-UART
   protocol as the real ESP32 (velocity, servo, LED commands in; T:1001
   telemetry at 20 Hz out)
3. Launches `master_beast.launch.py` with camera and LiDAR disabled
4. Verifies expected ROS nodes come up (`ugv_bringup`, `mqtt_bridge_node`,
   `robot_state_publisher`, `base_node`)
5. Verifies expected topics exist and are publishing (`/imu/data_raw`,
   `/odom/odom_raw`, `/voltage`, `/cmd_vel`, `/ugv/joint_states`)
6. Sends a test `cmd_vel` and confirms it reaches the mock

**Run locally (requires Docker):**

```bash
# 1. Build the image
docker build -t ugv-test .

# 2. Run the smoke test (mounts tests/ into the container)
docker run --rm --privileged \
  -v "$(pwd)/tests:/home/ws/tests" \
  ugv-test \
  bash /home/ws/tests/smoke_test.sh
```

The test exits `0` on success and `1` on failure with a summary of what went
wrong.

### Unit Tests

```bash
pip install -r requirements-dev.txt
pytest -v
```

## Monitoring

### Check ROS Topics

```bash
# List active topics
ros2 topic list

# Check publishing rate
ros2 topic hz /joint_states

# Echo topic messages
ros2 topic echo /joint_states
```

### Check Bridge Parameters

```bash
# Get rate limit
ros2 param get /mqtt_bridge_node ros2mqtt_rate_limit

# List all parameters
ros2 param list /mqtt_bridge_node
```

### Monitor MQTT Traffic

```bash
# Subscribe to all MQTT topics
mosquitto_sub -h mqtt.cyberwave.com -t '#' -v

# Monitor specific topic
mosquitto_sub -h mqtt.cyberwave.com -t 'cyberwave/joint/+/update' -v
```

## Uninstallation

To remove the service:

```bash
sudo ./scripts/uninstall.sh
```

This will:

- Stop and disable the systemd service
- Optionally remove the installation directory
- Optionally remove the service user

## Contributing

Contributions welcome! This is open-source software under the Apache-2.0 license.

## License

Apache-2.0 License. See the [LICENSE](LICENSE) file for details.

## Links

- **Repository**: https://github.com/cyberwave-os/cyberwave-edge-ros
- **Template**: https://github.com/cyberwave-os/edge-template
- **Documentation**: https://docs.cyberwave.com
- **Website**: https://cyberwave.com
- **Issues**: https://github.com/cyberwave-os/cyberwave-edge-ros/issues

## Related Projects

- [edge-template](https://github.com/cyberwave-os/edge-template) - Template for creating edge services in any language
- [cyberwave-python](https://github.com/cyberwave/cyberwave-python) - Python SDK for Cyberwave
- [cyberwave-edge-python](https://github.com/cyberwave-os/cyberwave-edge-python) - Python edge service for sensors and USB robots

## Support

For issues or questions:
1. Check the documentation in the `docs/` directory
2. Enable debug logging: `LOG_LEVEL=DEBUG`
3. Review bridge logs for error messages
4. Create an issue on GitHub
