#!/bin/bash

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./ugv_services_install.sh)"
    exit 1
fi

echo "Installing Cyberwave UGV Beast Boot Services..."

# Check for systemd
if ! pidof systemd >/dev/null 2>&1 && [ "$(cat /proc/1/comm)" != "systemd" ]; then
    echo "------------------------------------------------------------"
    echo "⚠️  WARNING: systemd is not running (PID 1 is $(cat /proc/1/comm))"
    echo "You appear to be in a Docker container or restricted shell."
    echo "systemctl commands will not work here."
    echo "------------------------------------------------------------"
    echo ""
    echo "I have created 'ugv_run.sh' for you instead."
    echo "To start the robot services manually, run:"
    echo "  ./ugv_run.sh"
    echo ""
    echo "If you want this to run automatically when the container starts,"
    echo "add './ugv_run.sh' to your entrypoint or .bashrc."
    
    chmod +x /home/ws/ugv_ws/ugv_run.sh
    exit 0
fi

WORKSPACE_PATH="/home/ws/ugv_ws"
MASTER_SERVICE="cyberwave-beast-master.service"

# --- Create the Master UGV service ---
# This service launches the core driver, sensors, MQTT bridge, and camera.
echo "Creating ${MASTER_SERVICE}..."
cat > /etc/systemd/system/${MASTER_SERVICE} << EOF
[Unit]
Description=Cyberwave UGV Beast Master Service (Core, Bridge, Camera)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORKSPACE_PATH}

# 1. Clean up /dev/video0 if it's locked by a previous crashed session
ExecStartPre=/bin/bash -c 'find /proc/*/fd -lname "/dev/video0" 2>/dev/null | cut -d/ -f3 | xargs -r kill -9 || true'
ExecStartPre=/bin/sleep 2

# 2. Launch the consolidated master launch file
ExecStart=/bin/bash -c 'source /opt/ros/humble/setup.bash && source ${WORKSPACE_PATH}/install/setup.bash && ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1'

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# --- Create the video grabber service ---
# This service ensures the WebRTC offer is sent to the cloud on boot,
# matching the Go2 edge pattern for automatic connectivity.
echo "Creating cyberwave-video-offer.service..."
cat > /etc/systemd/system/cyberwave-video-offer.service << EOF
[Unit]
Description=Cyberwave Video Offer Service (Trigger WebRTC Start)
After=${MASTER_SERVICE}
Wants=${MASTER_SERVICE}

[Service]
Type=oneshot
User=root
WorkingDirectory=${WORKSPACE_PATH}
# Wait for ROS nodes to initialize and bridge to connect to MQTT
ExecStartPre=/bin/sleep 15
# Trigger the start_video command via the ROS 2 service call provided by mqtt_bridge_node
ExecStart=/bin/bash -c 'source /opt/ros/humble/setup.bash && source ${WORKSPACE_PATH}/install/setup.bash && ros2 service call /mqtt_bridge_node/start_video std_srvs/srv/Trigger'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# --- Reload systemd and enable services ---
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling ${MASTER_SERVICE}..."
systemctl enable ${MASTER_SERVICE}

echo "Enabling cyberwave-video-offer.service..."
systemctl enable cyberwave-video-offer.service

echo "Starting ${MASTER_SERVICE}..."
systemctl restart ${MASTER_SERVICE}

echo "Starting cyberwave-video-offer.service..."
systemctl restart cyberwave-video-offer.service

echo ""
echo "Consolidated UGV Services installed successfully!"
echo "This system manages: Core Driver, IMU, Odometry, MQTT Bridge, and automatic WebRTC Offering."
echo ""
echo "Check status with:"
echo "  systemctl status ${MASTER_SERVICE}"
echo "  systemctl status cyberwave-video-offer.service"
echo ""
echo "View logs with:"
echo "  journalctl -u ${MASTER_SERVICE} -f"
echo "  journalctl -u cyberwave-video-offer.service -f"
echo ""

