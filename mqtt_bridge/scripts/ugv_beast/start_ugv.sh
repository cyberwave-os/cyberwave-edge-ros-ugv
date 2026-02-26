#!/bin/bash

clear
# UGV Environment Setup Script
# This script cleans up existing processes and starts the UGV environment in a tmux session.

# Default values
START_BRIDGE=true
ATTACH_LOGS=false

# Parse arguments
for arg in "$@"
do
    case $arg in
        --no-bridge)
        START_BRIDGE=false
        shift
        ;;
        --logs)
        ATTACH_LOGS=true
        shift
        ;;
        --help)
        echo "Usage: ./start_ugv.sh [OPTIONS]"
        echo "Options:"
        echo "  --no-bridge    Do not start the mqtt_bridge_node"
        echo "  --logs         Automatically attach to tmux session to view logs"
        exit 0
        ;;
    esac
done

# 1. Cleanup existing processes
echo "Cleaning up existing processes..."
sudo pkill -9 -f mqtt_bridge_node
sudo pkill -9 -f ugv_driver
sudo pkill -9 -f ugv_bringup
sudo pkill -9 -f usb_cam
sudo pkill -9 -f wheel_joint_publisher
sleep 2

# 2. Setup Variables
WORKSPACE_ROOT="/home/ws/ugv_ws"
SESSION_NAME="ugv_env"

# Create a new tmux session or kill existing one if it exists
tmux kill-session -t $SESSION_NAME 2>/dev/null
tmux new-session -d -s $SESSION_NAME -n "Core"

# Helper function to run a command in a new tmux pane
run_in_pane() {
    local cmd=$1
    local name=$2
    tmux new-window -t $SESSION_NAME -n "$name"
    tmux send-keys -t "$SESSION_NAME:$name" "cd $WORKSPACE_ROOT && export UGV_MODEL=ugv_beast && source /opt/ros/humble/setup.bash && source install/setup.bash && $cmd" C-m
}

echo "Starting UGV components in tmux session: $SESSION_NAME"

# 3. Start Master Launch File
echo "Starting Master Launch File (All Components)..."
tmux send-keys -t "$SESSION_NAME:Core" "cd $WORKSPACE_ROOT && export UGV_MODEL=ugv_beast && source /opt/ros/humble/setup.bash && source install/setup.bash && ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1 debug_logs:=true" C-m

echo "------------------------------------------------"
echo "UGV Environment started successfully!"
echo "Use 'tmux attach -t $SESSION_NAME' to view the processes."
echo "The master launch file runs all components: Core Driver, MQTT Bridge, Camera, IMU, Odometry."
echo "------------------------------------------------"

if [ "$ATTACH_LOGS" = true ]; then
    tmux attach -t $SESSION_NAME
fi
