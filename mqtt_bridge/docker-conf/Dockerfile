# syntax=docker/dockerfile:1.4
# Cyberwave UGV Beast Image with MQTT Bridge Integration
# This Dockerfile creates a complete ROS2 Humble environment with UGV workspace
# Build from cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge:
#   docker build -f docker-conf/Dockerfile -t cyberwaveos/ugv_beast:humble-ros-core-jammy .

# Use official ROS 2 Humble base image for ARM64 (Raspberry Pi/Jetson)
FROM ros:humble-ros-core-jammy

LABEL maintainer="Cyberwave Robotics Team"
LABEL description="Cyberwave UGV Beast with ROS2 Humble, MQTT Bridge, and complete workspace"
LABEL version="2.0"

# ============================================================================
# STAGE 1: Install System Packages and Dependencies
# ============================================================================

# Set non-interactive frontend and locale
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install locales and basic utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    curl \
    wget \
    gnupg2 \
    lsb-release \
    software-properties-common \
    ca-certificates \
    tmux \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install ROS 2 Humble Desktop and Navigation packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # ROS 2 Core packages (Desktop includes rclpy, launch_ros, lifecycle, etc.)
    ros-humble-desktop \
    ros-humble-ros-base \
    # Navigation stack (nav2)
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-nav2-behavior-tree \
    ros-humble-nav2-lifecycle-manager \
    # SLAM tools
    ros-humble-slam-toolbox \
    ros-humble-cartographer \
    ros-humble-cartographer-ros \
    # Robot State and TF2
    ros-humble-robot-state-publisher \
    ros-humble-joint-state-publisher \
    ros-humble-joint-state-publisher-gui \
    ros-humble-xacro \
    ros-humble-tf2-tools \
    ros-humble-tf2-ros \
    ros-humble-tf-transformations \
    # IMU and Sensors
    ros-humble-imu-complementary-filter \
    ros-humble-imu-tools \
    # Visualization (RViz)
    ros-humble-rqt-tf-tree \
    ros-humble-rqt-graph \
    ros-humble-rqt-robot-steering \
    ros-humble-rviz2 \
    ros-humble-rviz-common \
    ros-humble-rviz-default-plugins \
    # Simulation (Gazebo) - commented out if not available
    # ros-humble-gazebo-ros-pkgs \
    # Communication
    ros-humble-rosbridge-suite \
    ros-humble-rosbridge-server \
    ros-humble-diagnostic-updater \
    # Lifecycle management
    ros-humble-lifecycle \
    ros-humble-lifecycle-msgs \
    ros-humble-rclcpp-lifecycle \
    # Development tools
    python3-colcon-common-extensions \
    python3-colcon-ros \
    python3-rosdep \
    python3-vcstool \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCV and development libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    # OpenCV
    libopencv-dev \
    libopencv-contrib-dev \
    python3-opencv \
    # Build tools
    cmake \
    build-essential \
    git \
    # Math and optimization libraries
    libboost-all-dev \
    libeigen3-dev \
    libceres-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libatlas-base-dev \
    libsuitesparse-dev \
    # Note: libg2o-dev not available in Ubuntu 22.04 repos
    # This means teb_local_planner won't build, but other 21 packages will work
    # System libraries
    libhdf5-dev \
    libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

# Install SSH Server for remote access
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    openssh-client \
    openssh-sftp-server \
    rsync \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install audio support (for low battery warnings)
RUN apt-get update && apt-get install -y --no-install-recommends \
    alsa-utils \
    libasound2 \
    libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 2: Configure SSH
# ============================================================================

# Configure SSH to listen on port 23 with root access
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#Port 22/Port 23/g' /etc/ssh/sshd_config && \
    sed -i 's/^Port 22/Port 23/g' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd && \
    echo 'Port 23' >> /etc/ssh/sshd_config

# Set root password to 'ws'
RUN echo 'root:ws' | chpasswd

# ============================================================================
# STAGE 3: Install Python Dependencies
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir \
    cyberwave==0.3.3 \
    pydantic==2.12.5 \
    pyserial==3.5 \
    paho-mqtt==2.1.0 \
    opencv-contrib-python==4.10.0.84 \
    numpy==1.26.4 \
    mediapipe \
    requests \
    flask \
    flask-cors \
    websockets \
    aiortc \
    aioice \
    av \
    depthai \
    depthai-sdk

# ============================================================================
# STAGE 4: Create Hardware Access Groups
# ============================================================================

# Create hardware access groups (matching host system)
RUN groupadd -g 20 dialout 2>/dev/null || true && \
    groupadd -g 5 tty 2>/dev/null || true && \
    groupadd -g 44 video 2>/dev/null || true && \
    groupadd -g 29 audio 2>/dev/null || true && \
    groupadd -g 107 input 2>/dev/null || true && \
    usermod -aG dialout,tty,video,audio,input root

# ============================================================================
# STAGE 5: Initialize rosdep
# ============================================================================

RUN rosdep init || true && \
    rosdep update --rosdistro humble

# ============================================================================
# STAGE 5.5: Build and Install G2O from Source (for teb_local_planner)
# ============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    qtbase5-dev \
    libqt5opengl5-dev \
    libqglviewer-dev-qt5 \
    libsuitesparse-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build g2o from source
RUN cd /tmp && \
    git clone https://github.com/RainerKuemmerle/g2o.git && \
    cd g2o && \
    git checkout 20230223_git && \
    mkdir build && \
    cd build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DG2O_BUILD_APPS=OFF \
        -DG2O_BUILD_EXAMPLES=OFF \
        .. && \
    make -j2 && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/g2o

# ============================================================================
# STAGE 6: Clone and Setup UGV Workspace
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
# STAGE 7: Copy MQTT Bridge Integration
# ============================================================================

# Copy mqtt_bridge source (excluding docker-conf/, docs/, .env, README.md via .dockerignore)
COPY . /home/ws/ugv_ws/src/mqtt_bridge

# Create target directories for copied files
RUN mkdir -p /home/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/ \
    /home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/

# Copy specific mqtt_bridge files to their target locations (only files that exist)
COPY scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
COPY scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
COPY scripts/ugv_beast/ugv_bringup/setup.py /home/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
COPY scripts/ugv_beast/ugv_services_install.sh /home/ws/ugv_ws/ugv_services_install.sh
COPY scripts/ugv_beast/start_ugv.sh /home/ws/ugv_ws/start_ugv.sh

# ============================================================================
# STAGE 8: Build AprilTag Native Library
# ============================================================================

RUN bash -c "if [ -d /home/ws/ugv_ws/src/ugv_else/apriltag_ros/apriltag ]; then \
    cd /home/ws/ugv_ws/src/ugv_else/apriltag_ros/apriltag && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --target install && \
    cd /home/ws/ugv_ws/; \
    fi"

# ============================================================================
# STAGE 9: Build ROS2 Workspace (build_first.sh steps)
# ============================================================================
# 
# This stage replicates the build_first.sh script content:
# 
#   cd /home/ws/ugv_ws
#   colcon build --packages-select apriltag apriltag_msgs apriltag_ros \
#       cartographer costmap_converter_msgs costmap_converter emcl2 \
#       explore_lite openslam_gmapping slam_gmapping ldlidar \
#       rf2o_laser_odometry robot_pose_publisher teb_msgs teb_local_planner \
#       vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server \
#       ugv_base_node ugv_interface
#   
#   colcon build --packages-select ugv_bringup ugv_chat_ai ugv_description \
#       ugv_gazebo ugv_nav ugv_slam ugv_tools ugv_vision ugv_web_app \
#       --symlink-install
#   
#   echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
#   echo "eval \"$(register-python-argcomplete ros2)\"" >> ~/.bashrc
#   echo "eval \"$(register-python-argcomplete colcon)\"" >> ~/.bashrc
#   echo "source /home/ws/ugv_ws/install/setup.bash" >> ~/.bashrc
# 
# Note: bashrc configuration is done in STAGE 10
# ============================================================================

# Set G2O environment variables for CMake to find it
ENV G2O_ROOT=/usr
ENV CMAKE_PREFIX_PATH=/usr:${CMAKE_PREFIX_PATH}
ENV LD_LIBRARY_PATH=/usr/lib:${LD_LIBRARY_PATH}
ENV PKG_CONFIG_PATH=/usr/lib/pkgconfig:${PKG_CONFIG_PATH}

# First build pass: Core packages (matching build_first.sh line 1)
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
        ugv_base_node \
        ugv_interface \
    --parallel-workers 2 \
    --executor sequential \
    --continue-on-error || true"

# Second build pass: Main UGV packages with symlink-install (matching build_first.sh line 2)
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
    --continue-on-error || true"

# Build mqtt_bridge package if setup.py exists
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    if [ -f src/mqtt_bridge/setup.py ]; then \
        colcon build --packages-select mqtt_bridge --symlink-install; \
    fi"

# ============================================================================
# STAGE 10: Configure Bash Environment
# ============================================================================
# 
# This stage replicates the bashrc configuration from build_first.sh:
#   echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
#   echo "eval \"$(register-python-argcomplete ros2)\"" >> ~/.bashrc
#   echo "eval \"$(register-python-argcomplete colcon)\"" >> ~/.bashrc
#   echo "source /home/ws/ugv_ws/install/setup.bash" >> ~/.bashrc
# 
# Plus additional environment variables for ROS 2 networking
# ============================================================================

# Setup ROS2 environment in bashrc (matching build_first.sh lines 3-6)
RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "eval \"\$(register-python-argcomplete ros2)\"" >> /root/.bashrc && \
    echo "eval \"\$(register-python-argcomplete colcon)\"" >> /root/.bashrc && \
    echo "source /home/ws/ugv_ws/install/setup.bash 2>/dev/null || true" >> /root/.bashrc && \
    echo "export ROS_DOMAIN_ID=0" >> /root/.bashrc && \
    echo "export ROS_LOCALHOST_ONLY=0" >> /root/.bashrc && \
    echo "cd /home/ws/ugv_ws" >> /root/.bashrc

# ============================================================================
# STAGE 11: Set Permissions and Make Scripts Executable
# ============================================================================

RUN chmod +x /home/ws/ugv_ws/*.sh 2>/dev/null || true && \
    chmod +x /home/ws/ugv_ws/src/ugv_else/ldlidar/scripts/*.sh 2>/dev/null || true

# ============================================================================
# STAGE 12: Cleanup
# ============================================================================

# Clean up build artifacts to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /root/.cache

# ============================================================================
# FINAL CONFIGURATION
# ============================================================================

# Set environment variables
ENV ROS_DISTRO=humble
ENV ROS_VERSION=2
ENV UGV_MODEL=ugv_beast
ENV LDLIDAR_MODEL=ld19
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV PYTHONUNBUFFERED=1
ENV DISPLAY=:0
ENV PULSE_SERVER=unix:/run/user/1000/pulse/native
ENV WORKSPACE_PATH=/home/ws/ugv_ws
ENV ROS_DOMAIN_ID=0
ENV ROS_LOCALHOST_ONLY=0
ENV AUTORUN=1

# Working directory
WORKDIR /home/ws/ugv_ws

# Expose SSH port 23 and common ROS ports
EXPOSE 23 11311 11345

# Create SSH entrypoint script
RUN echo '#!/bin/bash\n\
service ssh start\n\
exec "$@"' > /ssh_entrypoint.sh && \
    chmod +x /ssh_entrypoint.sh

# Set entrypoint to start SSH and source ROS
ENTRYPOINT ["/ssh_entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# ============================================================================
# BUILD INSTRUCTIONS
# ============================================================================
# 
# To build this image:
# 
# 1. Navigate to the mqtt_bridge directory:
#    cd cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge
# 
# 2. Build the image:
#    docker build -f docker-conf/Dockerfile -t cyberwaveos/ugv_beast:humble-ros-core-jammy .
# 
# 3. Run the container with full hardware access:
#    docker run -dit \
#      --name ugv_beast \
#      --privileged \
#      --net=host \
#      -v /dev:/dev \
#      --device=/dev/ttyAMA0 \
#      --device=/dev/ttyACM0 \
#      --group-add dialout \
#      --cap-add=SYS_RAWIO \
#      --cap-add=NET_ADMIN \
#      -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
#      -e DISPLAY="${DISPLAY}" \
#      cyberwaveos/ugv_beast:humble-ros-core-jammy
# 
# 4. SSH into the container:
#    ssh root@<container-ip> -p 23
#    Password: ws
# 
# ============================================================================
# MAINTENANCE NOTES
# ============================================================================
# 
# To update the image:
# 1. Update source code in cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge/
# 2. Rebuild: docker build -f docker-conf/Dockerfile -t cyberwaveos/ugv_beast:humble-ros-core-jammy-v2 .
# 3. Test the new image
# 4. Tag as latest: docker tag cyberwaveos/ugv_beast:humble-ros-core-jammy-v2 cyberwaveos/ugv_beast:humble-ros-core-jammy
# 
# To add new dependencies:
# - System packages: Add to STAGE 1 apt-get install
# - Python packages: Add to STAGE 3 pip3 install
# - ROS2 packages: Add to STAGE 9 colcon build
# 
# Hardware Access Requirements:
# - Serial ports: /dev/ttyAMA0, /dev/ttyACM0
# - Groups: dialout (20), tty (5), video (44), audio (29), input (107)
# - Capabilities: CAP_SYS_RAWIO, CAP_NET_ADMIN, CAP_SYS_ADMIN
# 
# ============================================================================
# VERIFICATION CHECKLIST
# ============================================================================
# 
# After building, verify the following in the container:
# 
# ROS 2 Installation:
#   ✓ ROS Distribution: ROS 2 Humble
#   ✓ Full desktop installation with navigation, SLAM, visualization
#   ✓ Navigation stack (nav2, nav2-lifecycle-manager)
#   ✓ SLAM tools (cartographer, slam_toolbox)
#   ✓ TF2, robot_state_publisher
#   ✓ RViz visualization
#   ✓ Lifecycle management
# 
# Python Environment:
#   ✓ Python 3.10+ (from Ubuntu 22.04 Jammy)
#   ✓ ROS 2 Python libraries (rclpy, launch_ros - from ros-humble-desktop)
#   ✓ pyserial 3.5 - for serial communication
#   ✓ paho-mqtt 2.1.0 - MQTT client
#   ✓ opencv-contrib-python 4.10.0.84
#   ✓ numpy 1.26.4
#   ✓ aiortc (WebRTC)
#   ✓ depthai, depthai-sdk (OAK camera support)
#   ✓ cyberwave SDK 0.3.3
# 
# OpenCV Libraries:
#   ✓ libopencv-dev, libopencv-contrib-dev (system libraries)
#   ✓ python3-opencv
#   ✓ opencv-contrib-python (Python package with all modules)
# 
# Hardware Access Groups:
#   ✓ dialout (GID 20) - Serial port access
#   ✓ tty (GID 5) - TTY devices
#   ✓ video (GID 44) - Camera/video devices
#   ✓ audio (GID 29) - Audio devices
#   ✓ input (GID 107) - Input devices
#   ✓ root user added to all groups
# 
# Environment Variables:
#   ✓ ROS_DISTRO=humble
#   ✓ ROS_VERSION=2
#   ✓ UGV_MODEL=ugv_beast
#   ✓ LDLIDAR_MODEL=ld19
#   ✓ ROS workspace sourced at /home/ws/ugv_ws
#   ✓ ROS_DOMAIN_ID=0
#   ✓ ROS_LOCALHOST_ONLY=0
# 
# APT Repositories:
#   ✓ Ubuntu Jammy ports repositories
#   ✓ ROS 2 packages.ros.org repository
# 
# Workspace Structure:
#   ✓ /home/ws/ugv_ws cloned from ros2-humble-develop branch
#   ✓ AprilTag library built
#   ✓ ROS 2 packages built in two phases
#   ✓ mqtt_bridge integrated
# 
# To verify after container starts:
#   docker exec -it ugv_beast bash
#   - Check ROS: ros2 --version
#   - Check Python: python3 --version && pip3 list
#   - Check OpenCV: python3 -c "import cv2; print(cv2.__version__)"
#   - Check groups: groups
#   - Check workspace: ls /home/ws/ugv_ws/install
#   - Check serial ports: ls -l /dev/ttyAMA0 /dev/ttyACM0
# 
# ============================================================================
