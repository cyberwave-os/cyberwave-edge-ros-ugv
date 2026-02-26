#!/bin/bash
################################################################################
# UGV ROS 2 Jazzy Source Code Fixes
# Applies all necessary patches for ROS 2 Jazzy compatibility
################################################################################

set -e

WORKSPACE="/home/ubuntu/ws/ugv_ws"

echo "🔧 Applying ROS 2 Jazzy compatibility fixes..."

# Fix 1: emcl2 - Add <cstdint> include
echo "  Fixing emcl2..."
if [ -f "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h" ]; then
    if ! grep -q "#include <cstdint>" "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h"; then
        sed -i '/#include <string>/a #include <cstdint>' \
            "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Pose.h"
    fi
fi

if [ -f "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h" ]; then
    if ! grep -q "#include <cstdint>" "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h"; then
        sed -i '/#include <vector>/a #include <cstdint>' \
            "$WORKSPACE/src/ugv_else/emcl2_ros2/include/emcl2/Scan.h"
    fi
fi

# Fix 2: ldlidar - Add <pthread.h> include
echo "  Fixing ldlidar..."
if [ -f "$WORKSPACE/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp" ]; then
    if ! grep -q "#include <pthread.h>" "$WORKSPACE/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp"; then
        sed -i '/^#else$/a #include <pthread.h>' \
            "$WORKSPACE/src/ugv_else/ldlidar/ldlidar_driver/src/logger/log_module.cpp"
    fi
fi

# Fix 3: slam_gmapping - Change .h to .hpp
echo "  Fixing slam_gmapping..."
if [ -f "$WORKSPACE/src/ugv_else/gmapping/slam_gmapping/include/slam_gmapping/slam_gmapping.h" ]; then
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h|tf2_geometry_msgs/tf2_geometry_msgs.hpp|g' \
        "$WORKSPACE/src/ugv_else/gmapping/slam_gmapping/include/slam_gmapping/slam_gmapping.h"
fi

# Fix 4: explore_lite - Replace execute_callback() with makePlan()
echo "  Fixing explore_lite..."
if [ -f "$WORKSPACE/src/ugv_else/explore_lite/src/explore.cpp" ]; then
    sed -i 's|exploring_timer_->execute_callback();|makePlan();|g' \
        "$WORKSPACE/src/ugv_else/explore_lite/src/explore.cpp"
fi

# Fix 5: apriltag_ros - Change .h to .hpp
echo "  Fixing apriltag_ros..."
if [ -f "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp" ]; then
    sed -i 's|cv_bridge/cv_bridge\.h|cv_bridge/cv_bridge.hpp|g' \
        "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
    sed -i 's|image_geometry/pinhole_camera_model\.h|image_geometry/pinhole_camera_model.hpp|g' \
        "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag_ros/include/AprilTagNode.hpp"
fi

if [ -f "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp" ]; then
    sed -i 's|cv_bridge/cv_bridge\.h|cv_bridge/cv_bridge.hpp|g' \
        "$WORKSPACE/src/ugv_else/apriltag_ros/apriltag_ros/src/AprilTagNode.cpp"
fi

# Fix 6: costmap_converter - Change .h to .hpp
echo "  Fixing costmap_converter..."
find "$WORKSPACE/src/ugv_else/costmap_converter" -type f \( -name "*.h" -o -name "*.cpp" \) 2>/dev/null | while read file; do
    sed -i 's|cv_bridge/cv_bridge\.h|cv_bridge/cv_bridge.hpp|g' "$file" 2>/dev/null || true
    sed -i 's|tf2_geometry_msgs/tf2_geometry_msgs\.h|tf2_geometry_msgs/tf2_geometry_msgs.hpp|g' "$file" 2>/dev/null || true
done

# Fix 7: teb_local_planner - Add multiarch paths
echo "  Fixing teb_local_planner..."
if [ -f "$WORKSPACE/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake" ]; then
    if ! grep -q "lib/aarch64-linux-gnu" "$WORKSPACE/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"; then
        sed -i 's|PATH_SUFFIXES lib|PATH_SUFFIXES lib lib/aarch64-linux-gnu lib/x86_64-linux-gnu|g' \
            "$WORKSPACE/src/ugv_else/teb_local_planner/teb_local_planner/cmake_modules/FindG2O.cmake"
    fi
fi

echo "✅ All ROS 2 Jazzy compatibility fixes applied successfully!"
