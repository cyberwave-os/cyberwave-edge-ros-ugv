#!/bin/bash

# UGV Environment Setup Script
#
# Starts the UGV ROS 2 stack. Supports two modes:
#   - Foreground (default): runs ros2 launch directly. Used as Docker CMD
#     when started by cyberwave-edge-core.
#   - Tmux (--tmux): runs in a tmux session for interactive development.
#
# Environment variables (set by edge core or entrypoint.sh):
#   CYBERWAVE_TOKEN         - API token for MQTT bridge
#   CYBERWAVE_TWIN_UUID     - Digital twin UUID
#   CYBERWAVE_MQTT_HOST     - MQTT broker hostname
#   CYBERWAVE_ENVIRONMENT   - Topic prefix (empty = production)

ATTACH_LOGS=false
USE_TMUX=false

for arg in "$@"; do
    case $arg in
        --tmux)
            USE_TMUX=true
            shift
            ;;
        --logs)
            ATTACH_LOGS=true
            shift
            ;;
        --help)
            echo "Usage: ./start_ugv.sh [OPTIONS]"
            echo "Options:"
            echo "  --tmux    Run in a tmux session (interactive mode)"
            echo "  --logs    Attach to tmux session after starting (implies --tmux)"
            exit 0
            ;;
    esac
done

if [ "$ATTACH_LOGS" = true ]; then
    USE_TMUX=true
fi

WORKSPACE_ROOT="/home/ws/ugv_ws"

# Cleanup stale processes
pkill -9 -f mqtt_bridge_node 2>/dev/null || true
pkill -9 -f ugv_bringup 2>/dev/null || true
pkill -9 -f usb_cam 2>/dev/null || true
sleep 1

# Source ROS environment
source /opt/ros/humble/setup.bash
source "$WORKSPACE_ROOT/install/setup.bash" 2>/dev/null || true
export UGV_MODEL=ugv_beast

LAUNCH_CMD="ros2 launch ugv_bringup master_beast.launch.py robot_id:=robot_ugv_beast_v1 debug_logs:=true"

if [ "$USE_TMUX" = true ]; then
    SESSION_NAME="ugv_env"
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
    tmux new-session -d -s "$SESSION_NAME" -n "Core"
    tmux send-keys -t "$SESSION_NAME:Core" "cd $WORKSPACE_ROOT && source /opt/ros/humble/setup.bash && source install/setup.bash && export UGV_MODEL=ugv_beast && $LAUNCH_CMD" C-m

    echo "UGV started in tmux session: $SESSION_NAME"
    echo "  tmux attach -t $SESSION_NAME"

    if [ "$ATTACH_LOGS" = true ]; then
        tmux attach -t "$SESSION_NAME"
    fi
else
    echo "Starting UGV in foreground mode..."
    cd "$WORKSPACE_ROOT"
    exec $LAUNCH_CMD
fi
