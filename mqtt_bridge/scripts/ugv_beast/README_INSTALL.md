UGV Beast Service Installation Guide
===================================

Purpose
-------
This folder contains the installer for the Cyberwave UGV Beast services.
It creates a systemd service to launch the full robot stack, including
`mqtt_bridge_node`, on boot. If systemd is not available (e.g., container),
the installer creates a manual startup script instead.

Key Files
---------
- Installation script:
  `src/mqtt_bridge/scripts/ugv_beast/ugv_services_install.sh`
- Optional root-level copy:
  `/home/ws/ugv_ws/ugv_services_install.sh`

What the Installer Does
-----------------------
1) Checks if systemd is available.
2) If systemd is NOT available:
   - Generates `/home/ws/ugv_ws/ugv_run.sh`
   - That script manually sources ROS + workspace and launches the stack.
3) If systemd IS available:
   - Creates `cyberwave-beast-master.service`
   - Sets WorkingDirectory and ROS environment
   - Launches `master_beast.launch.py`
   - Enables and restarts the service

Environment Setup (important)
-----------------------------
Both the manual script and the systemd service:
- Source ROS 2: `/opt/ros/humble/setup.bash`
- Source workspace: `/home/ws/ugv_ws/install/setup.bash`

This is required so `ros2 launch` can find `mqtt_bridge_node` and the rest of
the installed packages.

Manual Script Creation (when no systemd)
----------------------------------------
If systemd is missing, the installer writes this script to
`/home/ws/ugv_ws/ugv_run.sh`. It:
- Clears `/dev/video0` if locked
- Sources the ROS + workspace environment
- Launches `master_beast.launch.py`

Systemd Service (when systemd exists)
-------------------------------------
The installer creates `cyberwave-beast-master.service` with:
- Clean up of `/dev/video0`
- `ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1`
- Automatic restart on failure

How to Run the Installer
------------------------
```bash
sudo ./ugv_services_install.sh
```

How to Manage the Service
-------------------------
- Status: `systemctl status cyberwave-beast-master.service`
- Logs: `journalctl -u cyberwave-beast-master.service -f`
- Restart: `sudo systemctl restart cyberwave-beast-master.service`

Reference Script (for rebuilds)
-------------------------------
If you need to recreate the installer manually, use the content below:

```bash
#!/bin/bash

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./ugv_services_install.sh)"
    exit 1
fi

echo "Installing Cyberwave UGV Beast Boot Services..."

# Check for systemd (Skip if in Docker/Restricted shell)
if ! pidof systemd >/dev/null 2>&1 && [ "$(cat /proc/1/comm)" != "systemd" ]; then
    echo "------------------------------------------------------------"
    echo "⚠️  WARNING: systemd is not running (PID 1 is $(cat /proc/1/comm))"
    echo "You appear to be in a Docker container or restricted shell."
    echo "systemctl commands will not work here."
    echo "------------------------------------------------------------"
    echo ""
    echo "Creating 'ugv_run.sh' for manual startup..."
    # Create a manual runner script if systemd is missing
    cat > /home/ws/ugv_ws/ugv_run.sh << EOF
#!/bin/bash
WORKSPACE_PATH="/home/ws/ugv_ws"
echo "🚀 Starting UGV Services Manually..."
find /proc/*/fd -lname "/dev/video0" 2>/dev/null | cut -d/ -f3 | xargs -r kill -9 || true
source /opt/ros/humble/setup.bash
source \${WORKSPACE_PATH}/install/setup.bash
ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1
EOF
    chmod +x /home/ws/ugv_ws/ugv_run.sh
    echo "Done. Run it with: ./ugv_run.sh"
    exit 0
fi

WORKSPACE_PATH="/home/ws/ugv_ws"
MASTER_SERVICE="cyberwave-beast-master.service"

# --- Create the Master UGV service ---
echo "Creating \${MASTER_SERVICE}..."
cat > /etc/systemd/system/\${MASTER_SERVICE} << EOF
[Unit]
Description=Cyberwave UGV Beast Master Service (Core, Bridge, Camera)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=\${WORKSPACE_PATH}

# Clean up /dev/video0 if locked
ExecStartPre=/bin/bash -c 'find /proc/*/fd -lname "/dev/video0" 2>/dev/null | cut -d/ -f3 | xargs -r kill -9 || true'
ExecStartPre=/bin/sleep 2

# Launch Consolidated Master
ExecStart=/bin/bash -c 'source /opt/ros/humble/setup.bash && source \${WORKSPACE_PATH}/install/setup.bash && ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1'

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# --- Reload systemd and enable services ---
echo "Reloading systemd daemon..."
systemctl daemon-reload
systemctl enable \${MASTER_SERVICE}
systemctl restart \${MASTER_SERVICE}

echo "Consolidated UGV Services installed successfully!"
```
```
