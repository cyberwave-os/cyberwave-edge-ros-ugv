#!/bin/bash
# UGV Start Script
# This is a PLACEHOLDER - replace with your actual start_ugv.sh
#
# Expected location in image:
#   /home/ubuntu/ws/ugv_ws/start_ugv.sh

set -e

echo "🚀 Starting UGV Beast..."

# Source ROS 2 Jazzy
source /opt/ros/jazzy/setup.bash
source /home/ubuntu/ws/ugv_ws/install/setup.bash

# Set environment
export UGV_MODEL=ugv_beast
export ROS_DOMAIN_ID=0

# Launch UGV
echo "Launching UGV with model: $UGV_MODEL"
ros2 launch ugv_bringup master_beast.launch.py

# Alternative: Launch multiple components
# ros2 launch ugv_bringup robot_state_publisher.launch.py &
# sleep 2
# ros2 launch ugv_nav navigation.launch.py &
# sleep 2
# ros2 launch ugv_vision camera.launch.py

echo "✅ UGV started!"
