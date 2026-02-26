# syntax=docker/dockerfile:1.4
#
# Cyberwave Edge ROS UGV — Complete UGV Beast + MQTT Bridge image
#
# Build context: project root (cyberwave-edge-ros-ugv/)
#   docker build -t cyberwaveos/edge-ros-ugv:latest .
#
# Run:
#   docker run -dit --name ugv_beast --privileged --net=host \
#     -v /dev:/dev -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
#     -e DISPLAY="${DISPLAY}" cyberwaveos/edge-ros-ugv:latest

FROM ros:humble-ros-core-jammy

LABEL maintainer="Cyberwave Robotics Team"
LABEL description="Cyberwave Edge ROS UGV: ROS 2 Humble + UGV Beast workspace + MQTT Bridge"

# ==========================================================================
# 1. System packages & ROS 2 Desktop + Navigation
# ==========================================================================

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    locales curl wget gnupg2 lsb-release software-properties-common \
    ca-certificates tmux \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-desktop \
    ros-humble-ros-base \
    # Navigation 2
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-nav2-behavior-tree \
    ros-humble-nav2-lifecycle-manager \
    # SLAM
    ros-humble-slam-toolbox \
    ros-humble-cartographer \
    ros-humble-cartographer-ros \
    # TF / Robot State
    ros-humble-robot-state-publisher \
    ros-humble-joint-state-publisher \
    ros-humble-joint-state-publisher-gui \
    ros-humble-xacro \
    ros-humble-tf2-tools \
    ros-humble-tf2-ros \
    ros-humble-tf-transformations \
    # IMU / Sensors
    ros-humble-imu-complementary-filter \
    ros-humble-imu-tools \
    # Visualization
    ros-humble-rqt-tf-tree \
    ros-humble-rqt-graph \
    ros-humble-rqt-robot-steering \
    ros-humble-rviz2 \
    ros-humble-rviz-common \
    ros-humble-rviz-default-plugins \
    # Communication & lifecycle
    ros-humble-rosbridge-suite \
    ros-humble-rosbridge-server \
    ros-humble-diagnostic-updater \
    ros-humble-lifecycle \
    ros-humble-lifecycle-msgs \
    ros-humble-rclcpp-lifecycle \
    # Dev tools
    python3-colcon-common-extensions \
    python3-colcon-ros \
    python3-rosdep \
    python3-vcstool \
    python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# OpenCV, build tools, math / optimization libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libopencv-dev libopencv-contrib-dev python3-opencv \
    cmake build-essential git \
    libboost-all-dev libeigen3-dev libceres-dev \
    libgoogle-glog-dev libgflags-dev libatlas-base-dev libsuitesparse-dev \
    libhdf5-dev libkrb5-dev \
    && rm -rf /var/lib/apt/lists/*

# SSH server (remote debug access on port 23)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server openssh-client openssh-sftp-server rsync tree \
    && rm -rf /var/lib/apt/lists/*

# Audio (low-battery warnings)
RUN apt-get update && apt-get install -y --no-install-recommends \
    alsa-utils libasound2 libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

# ==========================================================================
# 2. SSH configuration (port 23, root login)
# ==========================================================================

RUN mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh && \
    sed -i 's/#Port 22/Port 23/g'                              /etc/ssh/sshd_config && \
    sed -i 's/^Port 22/Port 23/g'                              /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && \
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g'         /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config && \
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g'  /etc/ssh/sshd_config && \
    sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' \
        -i /etc/pam.d/sshd && \
    echo 'Port 23' >> /etc/ssh/sshd_config && \
    echo 'root:ws' | chpasswd

# ==========================================================================
# 3. Python dependencies
# ==========================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir \
        pydantic \
        pyserial \
        mediapipe \
        requests \
        flask \
        flask-cors \
        websockets \
        aioice \
        depthai \
        depthai-sdk \
    && rm /tmp/requirements.txt

# ==========================================================================
# 4. Hardware access groups
# ==========================================================================

RUN groupadd -g 20  dialout 2>/dev/null || true && \
    groupadd -g 5   tty     2>/dev/null || true && \
    groupadd -g 44  video   2>/dev/null || true && \
    groupadd -g 29  audio   2>/dev/null || true && \
    groupadd -g 107 input   2>/dev/null || true && \
    usermod -aG dialout,tty,video,audio,input root

# ==========================================================================
# 5. rosdep
# ==========================================================================

RUN rosdep init || true && rosdep update --rosdistro humble

# ==========================================================================
# 6. Build G2O from source (required by teb_local_planner)
# ==========================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    qtbase5-dev libqt5opengl5-dev libqglviewer-dev-qt5 libsuitesparse-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    git clone https://github.com/RainerKuemmerle/g2o.git && \
    cd g2o && git checkout 20230223_git && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
          -DG2O_BUILD_APPS=OFF -DG2O_BUILD_EXAMPLES=OFF .. && \
    make -j2 && make install && ldconfig && \
    cd / && rm -rf /tmp/g2o

ENV G2O_ROOT=/usr \
    CMAKE_PREFIX_PATH=/usr:${CMAKE_PREFIX_PATH} \
    LD_LIBRARY_PATH=/usr/lib:${LD_LIBRARY_PATH} \
    PKG_CONFIG_PATH=/usr/lib/pkgconfig:${PKG_CONFIG_PATH}

# ==========================================================================
# 7. Clone UGV Beast workspace
# ==========================================================================

RUN mkdir -p /home/ws
WORKDIR /home/ws

RUN bash -c " \
    for i in {1..5}; do \
        git clone -b ros2-humble-develop https://github.com/DUDULRX/ugv_ws.git && break || { \
            echo 'Clone attempt '\$i' failed, retrying in 10s…'; sleep 10; \
        }; \
    done"

WORKDIR /home/ws/ugv_ws

# ==========================================================================
# 8. Copy MQTT Bridge + UGV bringup overrides into workspace
# ==========================================================================

COPY mqtt_bridge/ /home/ws/ugv_ws/src/mqtt_bridge

RUN mkdir -p /home/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/ \
             /home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/

COPY mqtt_bridge/scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py \
     /home/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
COPY mqtt_bridge/scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py \
     /home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
COPY mqtt_bridge/scripts/ugv_beast/ugv_bringup/setup.py \
     /home/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
COPY mqtt_bridge/scripts/ugv_beast/ugv_services_install.sh \
     /home/ws/ugv_ws/ugv_services_install.sh
COPY mqtt_bridge/scripts/ugv_beast/start_ugv.sh \
     /home/ws/ugv_ws/start_ugv.sh

# ==========================================================================
# 9. Build AprilTag native library (if present in ugv_ws)
# ==========================================================================

RUN bash -c "if [ -d /home/ws/ugv_ws/src/ugv_else/apriltag_ros/apriltag ]; then \
    cd /home/ws/ugv_ws/src/ugv_else/apriltag_ros/apriltag && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --target install && \
    cd /home/ws/ugv_ws; fi"

# ==========================================================================
# 10. Build ROS 2 workspace (two-pass, mirrors build_first.sh)
# ==========================================================================

# Pass 1 — core / third-party packages
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    colcon build --packages-select \
        apriltag apriltag_msgs apriltag_ros \
        cartographer costmap_converter_msgs costmap_converter \
        emcl2 explore_lite openslam_gmapping slam_gmapping \
        ldlidar rf2o_laser_odometry robot_pose_publisher \
        teb_msgs teb_local_planner \
        vizanti vizanti_cpp vizanti_demos vizanti_msgs vizanti_server \
        ugv_base_node ugv_interface \
    --parallel-workers 2 --executor sequential --continue-on-error || true"

# Pass 2 — main UGV packages (symlink-install for easier iteration)
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    colcon build --packages-select \
        ugv_bringup ugv_chat_ai ugv_description \
        ugv_gazebo ugv_nav ugv_slam ugv_tools \
        ugv_vision ugv_web_app \
    --symlink-install --parallel-workers 2 \
    --executor sequential --continue-on-error"

# Pass 3 — mqtt_bridge
RUN bash -c "source /opt/ros/humble/setup.bash && \
    cd /home/ws/ugv_ws && \
    if [ -f src/mqtt_bridge/setup.py ]; then \
        colcon build --packages-select mqtt_bridge --symlink-install; \
    fi"

# ==========================================================================
# 11. Shell environment
# ==========================================================================

RUN echo "source /opt/ros/humble/setup.bash"                        >> /root/.bashrc && \
    echo 'eval "$(register-python-argcomplete ros2)"'               >> /root/.bashrc && \
    echo 'eval "$(register-python-argcomplete colcon)"'             >> /root/.bashrc && \
    echo "source /home/ws/ugv_ws/install/setup.bash 2>/dev/null || true" >> /root/.bashrc && \
    echo "export ROS_DOMAIN_ID=0"                                   >> /root/.bashrc && \
    echo "export ROS_LOCALHOST_ONLY=0"                               >> /root/.bashrc && \
    echo "cd /home/ws/ugv_ws"                                        >> /root/.bashrc

# ==========================================================================
# 12. Permissions & cleanup
# ==========================================================================

RUN chmod +x /home/ws/ugv_ws/*.sh 2>/dev/null || true && \
    chmod +x /home/ws/ugv_ws/src/ugv_else/ldlidar/scripts/*.sh 2>/dev/null || true

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /root/.cache

# ==========================================================================
# Runtime configuration
# ==========================================================================

ENV ROS_DISTRO=humble \
    ROS_VERSION=2 \
    UGV_MODEL=ugv_beast \
    LDLIDAR_MODEL=ld19 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONUNBUFFERED=1 \
    DISPLAY=:0 \
    PULSE_SERVER=unix:/run/user/1000/pulse/native \
    WORKSPACE_PATH=/home/ws/ugv_ws \
    ROS_DOMAIN_ID=0 \
    ROS_LOCALHOST_ONLY=0 \
    AUTORUN=1

WORKDIR /home/ws/ugv_ws

EXPOSE 23 11311 11345

RUN printf '#!/bin/bash\nservice ssh start\nexec "$@"\n' > /ssh_entrypoint.sh && \
    chmod +x /ssh_entrypoint.sh

ENTRYPOINT ["/ssh_entrypoint.sh"]
CMD ["/bin/bash"]
