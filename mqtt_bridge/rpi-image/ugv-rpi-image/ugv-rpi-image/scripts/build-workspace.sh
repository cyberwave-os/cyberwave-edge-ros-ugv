#!/bin/bash
################################################################################
# UGV ROS 2 Workspace Build Script
# Builds all packages in the correct order with appropriate settings
################################################################################

set -e

WORKSPACE="/home/ubuntu/ws/ugv_ws"
cd "$WORKSPACE"

echo "🔨 Building UGV ROS 2 Jazzy workspace..."

# Source ROS 2
source /opt/ros/jazzy/setup.bash

# Build apriltag library first
echo "Building apriltag library..."
if [ -d "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag" ]; then
    cd "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag"
    mkdir -p build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    make -j2
    sudo make install
    sudo ldconfig
fi

cd "$WORKSPACE"

# Build first set of packages sequentially (RAM-friendly)
echo "Building core packages..."
colcon build --executor sequential \
    --packages-select \
        apriltag apriltag_msgs apriltag_ros \
        cartographer costmap_converter_msgs costmap_converter \
        emcl2 explore_lite openslam_gmapping slam_gmapping \
        ldlidar robot_pose_publisher teb_msgs \
        vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server \
        ugv_base_node ugv_interface \
    --cmake-args -DCMAKE_BUILD_TYPE=Release

# Build rf2o with limited parallelism (RAM-intensive)
echo "Building rf2o_laser_odometry (single-threaded)..."
MAKEFLAGS=-j1 colcon build \
    --packages-select rf2o_laser_odometry \
    --parallel-workers 1 \
    --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_PARALLEL_LEVEL=1

# Build UGV application packages (lightweight Python packages)
echo "Building UGV application packages..."
source install/setup.bash
colcon build \
    --packages-select \
        ugv_bringup ugv_chat_ai ugv_description ugv_gazebo \
        ugv_nav ugv_slam ugv_tools ugv_vision ugv_web_app \
    --symlink-install

echo ""
echo "✅ Workspace built successfully!"
echo "📦 Packages installed: $(ls -1 install/ 2>/dev/null | wc -l)"
echo ""
echo "⚠️  Note: teb_local_planner skipped (G2O linking issue)"
echo "    Alternative: Use Nav2 DWB controller"
