# Robot Configuration Guide

This guide explains how to configure different robot types with the Cyberwave Edge ROS2 bridge.

## Overview

The bridge uses a mapping system to translate between ROS 2 topics/messages and MQTT/Cyberwave digital twin updates. Each robot type has its own configuration file in `mqtt_bridge/config/mappings/`.

## Available Robot Configurations

### 1. Default Configuration

**Robot ID**: `default`  
**File**: `mqtt_bridge/config/mappings/default.yaml`  
**Use Case**: Generic robots, testing, or as a starting point

```yaml
version: 1
robot_id: "default"
format: "json_by_name"
metadata:
  twin_uuid: "00000000-0000-0000-0000-000000000000"

joints: []  # No remapping

capabilities:
  upstream_mode: "joint"
```

**To use**:
```bash
export ROBOT_ID=default
ros2 run mqtt_bridge mqtt_bridge_node
```

### 2. Robot Arm Configuration

**Robot ID**: `robot_arm_v1`  
**File**: `mqtt_bridge/config/mappings/robot_arm_v1.yaml`  
**Use Case**: Robotic arms (UR3, UR5, UR7, UR10, etc.)

```yaml
version: 1
robot_id: "robot_arm_v1"
format: "json_by_name"
metadata:
  twin_uuid: "your-twin-uuid-here"

joints:
  - ros_name: "shoulder_pan_joint"
    mqtt_name: "shoulder_pan_joint"
    transform: {scale: 1.0, offset: 0.0}
  - ros_name: "shoulder_lift_joint"
    mqtt_name: "shoulder_lift_joint"
    transform: {scale: 1.0, offset: 0.0}
  # ... more joints

capabilities:
  upstream_mode: "joint"

io_configuration:
  tool0:
    enabled: true
    joint_name: "ee_fixed_joint"
    service_name: "/io_and_status_controller/set_io"
```

**Features**:
- Joint state publishing
- Joint name mapping
- Tool/gripper control via IO
- Position/velocity/effort reporting

**To use**:
```bash
export ROBOT_ID=robot_arm_v1
ros2 run mqtt_bridge mqtt_bridge_node
```

### 3. UGV Beast Configuration

**Robot ID**: `robot_ugv_beast_v1`  
**File**: `mqtt_bridge/config/mappings/robot_ugv_beast_v1.yaml`  
**Use Case**: Unmanned Ground Vehicles (wheeled robots)

```yaml
version: 1
robot_id: "robot_ugv_beast_v1"
metadata:
  twin_uuid: "your-twin-uuid-here"

command_registry: "mqtt_bridge.plugins.ugv_beast_command_handler.UGVBeastCommandRegistry"

internal_odometry:
  enabled: true
  track_width: 0.23
  wheel_radius: 0.04
  left_wheel_joints: ["left_up_wheel_link_joint", "left_down_wheel_link_joint"]
  right_wheel_joints: ["right_up_wheel_link_joint", "right_down_wheel_link_joint"]

camera:
  format: "yuv420p"

capabilities:
  upstream_mode: "pose"
```

**Features**:
- Pose-based telemetry (x, y, z, orientation)
- Internal odometry calculation
- Velocity command handling (`/cmd_vel`)
- Camera streaming
- Custom command handler for UGV-specific features

**To use**:
```bash
export ROBOT_ID=robot_ugv_beast_v1
ros2 run mqtt_bridge mqtt_bridge_node
```

## Creating a Custom Robot Configuration

### Step 1: Create Mapping File

Create a new file in `mqtt_bridge/config/mappings/your_robot_id.yaml`:

```yaml
version: 1
robot_id: "your_robot_id"
format: "json_by_name"
metadata:
  twin_uuid: "GET-FROM-CYBERWAVE-DASHBOARD"

# Define joint mappings (if applicable)
joints:
  - ros_name: "base_to_arm_joint"
    mqtt_name: "shoulder_joint"
    transform: {scale: 1.0, offset: 0.0}

capabilities:
  upstream_mode: "joint"  # Options: joint, pose, both
```

### Step 2: Configure Twin UUID

Get your twin UUID from the Cyberwave dashboard:
1. Log in to Cyberwave
2. Navigate to your project
3. Create or select a digital twin
4. Copy the UUID
5. Add it to your mapping file

### Step 3: Define Joint Mappings (Optional)

If your robot publishes joint states, map ROS joint names to digital twin joint names:

```yaml
joints:
  - ros_name: "ros_joint_name"       # Name in ROS /joint_states
    mqtt_name: "twin_joint_name"     # Name in digital twin
    transform:
      scale: 1.0                      # Multiply by this
      offset: 0.0                     # Add this offset
```

**Transform examples**:
- Convert degrees to radians: `scale: 0.0174533` (π/180)
- Invert direction: `scale: -1.0`
- Add offset: `offset: 1.57` (90 degrees)

### Step 4: Configure Capabilities

Choose how your robot reports telemetry:

```yaml
capabilities:
  upstream_mode: "joint"  # Joint angles/positions
  # OR
  upstream_mode: "pose"   # Position and orientation
  # OR
  upstream_mode: "both"   # Both joint and pose
```

### Step 5: Add Internal Odometry (Optional)

If your robot doesn't publish `/odom`, enable internal odometry:

```yaml
internal_odometry:
  enabled: true
  track_width: 0.3        # Distance between wheels (meters)
  wheel_radius: 0.05      # Wheel radius (meters)
  left_wheel_joints: ["left_wheel_joint"]
  right_wheel_joints: ["right_wheel_joint"]
```

### Step 6: Create Custom Command Handler (Optional)

For robot-specific commands (gripper, lights, sensors), create a plugin:

1. Create `mqtt_bridge/plugins/your_robot_handler.py`:

```python
from mqtt_bridge.command_handler import CommandRegistry


class YourRobotCommandRegistry(CommandRegistry):
    def __init__(self, node):
        super().__init__(node)
        # Initialize your custom commands
    
    def handle_command(self, command_type, data):
        if command_type == "custom_action":
            self._handle_custom_action(data)
        else:
            return super().handle_command(command_type, data)
    
    def _handle_custom_action(self, data):
        # Implement your custom logic
        pass
```

2. Register it in your mapping file:

```yaml
command_registry: "mqtt_bridge.plugins.your_robot_handler.YourRobotCommandRegistry"
```

### Step 7: Test Your Configuration

```bash
# Set robot ID
export ROBOT_ID=your_robot_id

# Run with debug logging
export LOG_LEVEL=DEBUG

# Start the bridge
ros2 run mqtt_bridge mqtt_bridge_node

# In another terminal, check topics
ros2 topic list
ros2 topic echo /joint_states
```

## Configuration Parameters

### Metadata

| Parameter | Required | Description |
|-----------|----------|-------------|
| `twin_uuid` | Yes | Digital twin UUID from Cyberwave dashboard |

### Joint Mapping

| Parameter | Required | Description |
|-----------|----------|-------------|
| `ros_name` | Yes | Joint name in ROS /joint_states topic |
| `mqtt_name` | Yes | Joint name in digital twin |
| `transform.scale` | No | Multiplication factor (default: 1.0) |
| `transform.offset` | No | Additive offset (default: 0.0) |

### Internal Odometry

| Parameter | Required | Description |
|-----------|----------|-------------|
| `enabled` | Yes | Enable internal odometry calculation |
| `track_width` | Yes | Distance between wheel centers (meters) |
| `wheel_radius` | Yes | Wheel radius (meters) |
| `left_wheel_joints` | Yes | List of left wheel joint names |
| `right_wheel_joints` | Yes | List of right wheel joint names |

### Capabilities

| Parameter | Options | Description |
|-----------|---------|-------------|
| `upstream_mode` | `joint`, `pose`, `both` | How to report robot state |

## Examples

### Example 1: Simple Arm with 3 Joints

```yaml
version: 1
robot_id: "simple_arm"
metadata:
  twin_uuid: "12345678-1234-1234-1234-123456789abc"

joints:
  - ros_name: "joint1"
    mqtt_name: "base_joint"
  - ros_name: "joint2"
    mqtt_name: "middle_joint"
  - ros_name: "joint3"
    mqtt_name: "end_joint"

capabilities:
  upstream_mode: "joint"
```

### Example 2: Mobile Robot with Odometry

```yaml
version: 1
robot_id: "mobile_robot"
metadata:
  twin_uuid: "87654321-4321-4321-4321-cba987654321"

internal_odometry:
  enabled: true
  track_width: 0.4
  wheel_radius: 0.08
  left_wheel_joints: ["left_wheel"]
  right_wheel_joints: ["right_wheel"]

capabilities:
  upstream_mode: "pose"
```

### Example 3: Hybrid Robot (Arm on Mobile Base)

```yaml
version: 1
robot_id: "hybrid_robot"
metadata:
  twin_uuid: "abcdef12-3456-7890-abcd-ef1234567890"

joints:
  - ros_name: "arm_joint_1"
    mqtt_name: "shoulder"
  - ros_name: "arm_joint_2"
    mqtt_name: "elbow"

internal_odometry:
  enabled: true
  track_width: 0.5
  wheel_radius: 0.1
  left_wheel_joints: ["left_wheel"]
  right_wheel_joints: ["right_wheel"]

capabilities:
  upstream_mode: "both"
```

## Troubleshooting

### Joint names don't match

**Problem**: Digital twin shows wrong joint positions

**Solution**: Check joint names in ROS vs. digital twin:
```bash
ros2 topic echo /joint_states
```

Update mapping file to match.

### Odometry drift

**Problem**: Robot position drifts over time

**Solution**: 
1. Verify wheel parameters (radius, track width)
2. Use native `/odom` topic if available
3. Enable sensor fusion with IMU

### Commands not working

**Problem**: MQTT commands don't reach robot

**Solution**:
1. Check source type filtering (only `"tele"` mode works)
2. Verify command handler is registered
3. Enable debug logging to see incoming commands

## Next Steps

- [Main README](../README.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Plugin Development](PLUGIN_DEVELOPMENT.md)
