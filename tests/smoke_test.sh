#!/usr/bin/env bash
set -eo pipefail

source /usr/local/bin/source_ros_setup.sh
if [ -f /home/ws/ugv_ws/install/setup.bash ]; then
    # shellcheck disable=SC1091
    source /home/ws/ugv_ws/install/setup.bash
fi

ROS_PACKAGES="$(ros2 pkg list)"
grep -qx 'mqtt_bridge' <<< "$ROS_PACKAGES"
grep -qx 'ugv_bringup' <<< "$ROS_PACKAGES"

MQTT_BRIDGE_EXECUTABLES="$(ros2 pkg executables mqtt_bridge)"
UGV_BRINGUP_EXECUTABLES="$(ros2 pkg executables ugv_bringup)"
grep -q 'mqtt_bridge_node' <<< "$MQTT_BRIDGE_EXECUTABLES"
grep -q 'ugv_integrated_driver' <<< "$UGV_BRINGUP_EXECUTABLES"
test -x /home/ws/ugv_ws/ugv_services_install.sh

python3 - <<'PY'
from mqtt_bridge.plugins.ugv_beast_command_handler import CommandRegistry

assert CommandRegistry.__name__ == "CommandRegistry"
PY

echo "UGV smoke test passed"
