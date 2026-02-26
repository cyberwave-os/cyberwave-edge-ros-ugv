#!/bin/bash
# Quick setup script to source ROS 2 Jazzy workspace

echo "🚀 Loading ROS 2 Jazzy workspace..."

source /opt/ros/jazzy/setup.bash
source /home/ubuntu/ws/ugv_ws/install/setup.bash
export UGV_MODEL=ugv_rover

echo "✅ ROS 2 Jazzy workspace loaded!"
echo "   ROS_DISTRO: $ROS_DISTRO"
echo "   UGV_MODEL: $UGV_MODEL"
