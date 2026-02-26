# Implementation Guide

This document provides guidance for implementing the complete MQTT bridge functionality.

## Overview

This repository provides the structure and documentation for the Cyberwave Edge ROS2 project. The actual implementation files should be copied from the reference implementation located at:

```
/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/
```

## Files to Copy

### Core Bridge Files

Copy these files from the source to `mqtt_bridge/`:

1. **mqtt_bridge_node.py** - Main ROS 2 node
   - Orchestrates MQTT connectivity
   - Manages ROS topic subscriptions
   - Delegates to specialized modules

2. **cyberwave_mqtt_adapter.py** - SDK wrapper
   - Cyberwave SDK integration
   - MQTT connection management
   - Message publishing/subscribing

3. **telemetry.py** - Telemetry management
   - Joint state accumulation
   - High-frequency feedback processing
   - Rate limiting logic

4. **health.py** - Health monitoring
   - Periodic heartbeats
   - System status reporting
   - Connection monitoring

5. **mapping.py** - Mapping system
   - Joint name transformations
   - Coordinate transforms
   - Configuration loading

6. **command_handler.py** - Command handling
   - Base command registry
   - Command routing
   - Response handling

7. **logger_shim.py** - Logging utilities
   - ROS 2 logging integration
   - Debug helpers

### Plugin Files

Copy these files from the source to `mqtt_bridge/plugins/`:

1. **internal_odometry.py** - Odometry calculation
   - Dead-reckoning for robots without native odometry
   - Wheel-based position estimation

2. **navigation_bridge.py** - Nav2 integration
   - Navigation stack integration
   - Goal handling
   - Path following

3. **ros_camera.py** - Camera streaming
   - WebRTC video streaming
   - ROS Image topic integration

4. **ugv_beast_command_handler.py** - UGV-specific commands
   - Example custom command handler
   - LED control, pan-tilt, etc.

## Copy Commands

Run these commands from your terminal:

```bash
# Set source and destination paths
SOURCE="/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/mqtt_bridge"
DEST="/Users/philiptambe/Documents/dev/cyberwave-edge-ros/mqtt_bridge"

# Copy core files
cp "$SOURCE/mqtt_bridge_node.py" "$DEST/"
cp "$SOURCE/cyberwave_mqtt_adapter.py" "$DEST/"
cp "$SOURCE/telemetry.py" "$DEST/"
cp "$SOURCE/health.py" "$DEST/"
cp "$SOURCE/mapping.py" "$DEST/"
cp "$SOURCE/command_handler.py" "$DEST/"
cp "$SOURCE/logger_shim.py" "$DEST/"

# Copy plugin files
cp "$SOURCE/plugins/internal_odometry.py" "$DEST/plugins/"
cp "$SOURCE/plugins/navigation_bridge.py" "$DEST/plugins/"
cp "$SOURCE/plugins/ros_camera.py" "$DEST/plugins/"
cp "$SOURCE/plugins/ugv_beast_command_handler.py" "$DEST/plugins/"

echo "Files copied successfully!"
```

## After Copying

### 1. Update Package Imports

The copied files may have import statements that need updating. Check and modify:

```python
# Before (from source)
from mqtt_bridge.mapping import RobotMapping

# After (should be the same in this case)
from mqtt_bridge.mapping import RobotMapping
```

### 2. Test the Installation

```bash
# Build the workspace
cd /Users/philiptambe/Documents/dev/cyberwave-edge-ros
source /opt/ros/humble/setup.bash
colcon build --symlink-install

# Source the workspace
source install/setup.bash

# Run the node
ros2 run mqtt_bridge mqtt_bridge_node
```

### 3. Verify Functionality

Check that the bridge:
- Connects to MQTT broker
- Subscribes to ROS topics
- Publishes to Cyberwave
- Handles commands
- Applies rate limiting

## Additional Documentation

If you need additional documentation files, copy from:

```bash
SOURCE_DOCS="/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/docs"
DEST_DOCS="/Users/philiptambe/Documents/dev/cyberwave-edge-ros/docs"

# Copy specific documentation
cp "$SOURCE_DOCS/edge-ros-ugv-beast-setup/edge-ros-ugv-beast.md" "$DEST_DOCS/"
cp "$SOURCE_DOCS/edge-ros-ur7-setup/edge-ros-ur7.md" "$DEST_DOCS/"
```

## Configuration Files

The configuration files (YAML) are already created in this repository. They are based on but adapted from the source:

- `mqtt_bridge/config/params.yaml` - Main configuration
- `mqtt_bridge/config/mappings/*.yaml` - Robot mappings

You may want to compare with the source and update if needed:

```bash
# Compare configurations
diff mqtt_bridge/config/params.yaml \
     /Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/config/params.yaml
```

## Testing

After implementation:

1. **Unit Tests**: Copy test files from source if available
2. **Integration Tests**: Test with actual ROS 2 setup
3. **Hardware Tests**: Test with physical robot

## Troubleshooting

If you encounter issues after copying:

1. **Import Errors**: Check Python path and package structure
2. **ROS Errors**: Verify ROS 2 is sourced correctly
3. **MQTT Errors**: Check credentials in `.env` file
4. **Build Errors**: Run `colcon build` with `--symlink-install`

## Next Steps

1. Copy the implementation files (see commands above)
2. Build and test the workspace
3. Configure for your specific robot
4. Deploy to production using installation scripts

## Reference

- Source Repository: `/Users/philiptambe/Documents/cyberwave/cyberwave-edge-nodes/cyberwave-ros2`
- Main README: `README.md`
- Robot Configuration: `docs/ROBOT_CONFIGURATION.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
