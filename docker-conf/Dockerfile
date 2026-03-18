# syntax=docker/dockerfile:1.4
# ============================================================================
# Cyberwave UGV Beast Image with MQTT Bridge Integration
# ============================================================================
# This Dockerfile adapts the dudulrx0601/ugv_rpi_ros_humble base image 
# to integrate the Cyberwave MQTT Bridge for UGV Beast.
#
# The base image already includes:
#   - ROS2 Humble
#   - openssh-server/client/sftp-server (SSH on port 23)
#   - cmake, libopencv-dev, python3-opencv
#   - ros-humble-robot-state-publisher, ros-humble-nav2-behavior-tree
#   - ros-humble-rqt-tf-tree
#   - pyserial, mediapipe, requests
#   - SSH configured: Port 23, PermitRootLogin yes
#   - ROS2 sourced in bashrc
#
# Build from cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge:
#   docker build -f docker-conf/Dockerfile -t cyberwaveos/cyb_ugv_beast:latest .
#
# ============================================================================

ARG BASE_IMAGE=dudulrx0601/ugv_rpi_ros_humble:ugv_rpi_ros_humble
FROM ${BASE_IMAGE}

LABEL maintainer="Cyberwave Robotics Team"
LABEL description="Cyberwave UGV Beast with MQTT Bridge Integration"
LABEL version="1.0"

# ============================================================================
# STAGE 1: Fix ROS GPG Key (expired key issue)
# ============================================================================

# Update the existing ROS2 keyring file with the new key
RUN apt-get update || true && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros2-latest-archive-keyring.gpg && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 2: Install Additional System Packages (only what's missing)
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    # File synchronization and utilities (not in base image)
    rsync \
    tree \
    git \
    # Audio utilities
    alsa-utils \
    # Python and build tools
    python3-pip \
    python3-argcomplete \
    build-essential \
    # Device management
    udev \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 3: Install Python Dependencies (only what's missing)
# ============================================================================
# Base image already has: pyserial, mediapipe, requests

RUN pip3 install --break-system-packages --no-cache-dir \
    cyberwave==0.3.24 \
    pydantic==2.12.5 \
    flask \
    av \
    aiortc \
    aioice

# ============================================================================
# STAGE 4: Clone UGV Workspace Repository
# ============================================================================

# Create workspace directory
RUN mkdir -p /home/ws

WORKDIR /home/ws

# Clone ugv_ws repository (ros2-humble-develop branch) with retries
RUN bash -c " \
    for i in {1..5}; do \
    git clone -b ros2-humble-develop https://github.com/DUDULRX/ugv_ws.git && break || { \
    echo 'Clone attempt '\$i' failed, retrying in 10 seconds...'; \
    sleep 10; \
    }; \
    done"

# Set working directory to ugv_ws
WORKDIR /home/ws/ugv_ws

# ============================================================================
# STAGE 5: Copy MQTT Bridge Integration
# ============================================================================
# Note: Build context is mqtt_bridge directory
# Excludes docker-conf/, docs/, .env, README.md via .dockerignore
# The cloned ugv_ws repo already has ugv_main/ugv_bringup structure

# Cache buster - pass --build-arg CACHEBUST=$(date +%s) to force rebuild from here
ARG CACHEBUST=1

# Copy mqtt_bridge source package
COPY . /home/ws/ugv_ws/src/mqtt_bridge

# Overwrite specific ugv_bringup files with Cyberwave customizations
COPY scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
COPY scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/
COPY scripts/ugv_beast/ugv_bringup/setup.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py

# Copy startup and service scripts
COPY scripts/ugv_beast/ugv_services_install.sh /home/ws/ugv_ws/ugv_services_install.sh
#COPY scripts/ugv_beast/start_ugv.sh /home/ws/ugv_ws/start_ugv.sh
#COPY scripts/ugv_beast/ugv_run.sh /home/ws/ugv_ws/ugv_run.sh

# Ensure ugv_integrated_driver entry point exists in setup.py
# First, verify the file was copied correctly
RUN echo "=== Verifying setup.py has ugv_integrated_driver ===" && \
    cat /home/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py && \
    grep -q "ugv_integrated_driver" /home/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py && \
    echo "=== ugv_integrated_driver entry point confirmed ===" || \
    (echo "ERROR: ugv_integrated_driver not found in setup.py" && exit 1)

# ============================================================================
# STAGE 6: Build ROS2 Workspace - First Pass (Core packages)
# ============================================================================
# Note: teb_local_planner may fail due to g2o detection issues,
# but the build continues with --continue-on-error

RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    colcon build --packages-select \
    apriltag \
    apriltag_msgs \
    apriltag_ros \
    cartographer \
    costmap_converter_msgs \
    costmap_converter \
    emcl2 \
    explore_lite \
    openslam_gmapping \
    slam_gmapping \
    ldlidar \
    rf2o_laser_odometry \
    robot_pose_publisher \
    teb_msgs \
    teb_local_planner \
    vizanti \
    vizanti_cpp \
    vizanti_demos \
    vizanti_msgs \
    vizanti_server \
    ugv_interface \
    --parallel-workers 2 \
    --executor sequential \
    --continue-on-error || true"

# Build ugv_base_node separately - critical for odometry
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    echo '=== Building ugv_base_node (odometry calculator) ===' && \
    colcon build --packages-select ugv_base_node --parallel-workers 2 && \
    echo '=== ugv_base_node built successfully ===' || \
    echo 'WARNING: ugv_base_node failed to build - will retry at container startup'"

# ============================================================================
# STAGE 7: Build ROS2 Workspace - Second Pass (Main UGV packages)
# ============================================================================

RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    colcon build --packages-select \
    ugv_bringup \
    ugv_chat_ai \
    ugv_description \
    ugv_gazebo \
    ugv_nav \
    ugv_slam \
    ugv_tools \
    ugv_vision \
    ugv_web_app \
    --symlink-install \
    --parallel-workers 2 \
    --executor sequential \
    --continue-on-error"

# ============================================================================
# STAGE 8: Build MQTT Bridge Package
# ============================================================================

RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    if [ -f src/mqtt_bridge/setup.py ]; then \
    colcon build --packages-select mqtt_bridge --symlink-install; \
    fi"

# ============================================================================
# STAGE 9: Set Permissions and Make Scripts Executable
# ============================================================================

RUN chmod +x /home/ws/ugv_ws/*.sh 2>/dev/null || true && \
    chmod +x /home/ws/ugv_ws/src/ugv_else/ldlidar/scripts/*.sh 2>/dev/null || true

# ============================================================================
# STAGE 10: Cleanup
# ============================================================================

# Clean up build artifacts to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /root/.cache

# ============================================================================
# FINAL CONFIGURATION
# ============================================================================

# Environment variables (some may already be set by base image)
ENV ROS_DISTRO=humble
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV WORKSPACE_PATH=/home/ws/ugv_ws

# Working directory
WORKDIR /home/ws/ugv_ws

# Expose common ROS ports
EXPOSE 11311 11345

# Clean-build mqtt_bridge with Release flags using the project script
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    bash src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh --logs"

ENTRYPOINT ["/home/ws/ugv_ws/ugv_services_install.sh"]