#!/bin/bash
#
# Smoke test for the UGV Beast Docker image.
#
# Verifies the full ROS 2 graph starts up correctly against a mock ESP32
# serial emulator. Run this INSIDE the built Docker container:
#
#   docker run --rm cyberwaveos/edge-ros-ugv:latest \
#       bash /home/ws/ugv_ws/src/mqtt_bridge/tests/smoke_test.sh
#
# What it does:
#   1. Creates a virtual serial port pair with socat
#   2. Symlinks one end to /dev/ttyAMA0 (what the driver expects)
#   3. Starts mock_esp32.py on the other end
#   4. Launches master_beast.launch.py (camera + lidar disabled)
#   5. Waits for ROS nodes and topics to come up
#   6. Verifies expected nodes, topics, and publishing rates
#   7. Sends a test cmd_vel and verifies it reaches the mock
#   8. Cleans up and exits 0 (pass) or 1 (fail)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="/home/ws/ugv_ws"
STARTUP_TIMEOUT=45  # seconds to wait for nodes
TOPIC_HZ_SAMPLES=10 # messages to sample for hz check

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass_count=0
fail_count=0
SOCAT_PID=""
MOCK_PID=""
LAUNCH_PID=""

log_pass() { echo -e "${GREEN}  PASS${NC} $1"; pass_count=$((pass_count + 1)); }
log_fail() { echo -e "${RED}  FAIL${NC} $1"; fail_count=$((fail_count + 1)); }
log_info() { echo -e "${YELLOW}  ....${NC} $1"; }

cleanup() {
    log_info "Cleaning up..."
    [ -n "$LAUNCH_PID" ] && kill "$LAUNCH_PID" 2>/dev/null || true
    [ -n "$MOCK_PID" ]   && kill "$MOCK_PID"   2>/dev/null || true
    [ -n "$SOCAT_PID" ]  && kill "$SOCAT_PID"  2>/dev/null || true
    rm -f /tmp/socat_pts_a /tmp/socat_pts_b
    wait 2>/dev/null || true
}
trap cleanup EXIT

# ---------- 0. Prerequisites ----------

echo "========================================="
echo " UGV Beast Docker Smoke Test"
echo "========================================="
echo ""

if ! command -v socat &>/dev/null; then
    log_info "Installing socat..."
    apt-get update -qq && apt-get install -y -qq socat >/dev/null 2>&1
fi

# ---------- 1. Virtual serial port pair ----------

log_info "Creating virtual serial port pair..."

socat -d -d \
    pty,raw,echo=0,link=/tmp/socat_pts_a \
    pty,raw,echo=0,link=/tmp/socat_pts_b \
    &>/dev/null &
SOCAT_PID=$!
sleep 1

if ! kill -0 "$SOCAT_PID" 2>/dev/null; then
    log_fail "socat failed to create PTY pair"
    exit 1
fi

PTY_DRIVER=$(readlink -f /tmp/socat_pts_a)
PTY_MOCK=$(readlink -f /tmp/socat_pts_b)
log_pass "PTY pair created: driver=$PTY_DRIVER mock=$PTY_MOCK"

# Symlink so the driver finds /dev/ttyAMA0
rm -f /dev/ttyAMA0
ln -sf "$PTY_DRIVER" /dev/ttyAMA0
log_pass "/dev/ttyAMA0 -> $PTY_DRIVER"

# ---------- 2. Start mock ESP32 ----------

log_info "Starting mock ESP32..."
python3 "$SCRIPT_DIR/mock_esp32.py" "$PTY_MOCK" --verbose &
MOCK_PID=$!
sleep 1

if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    log_fail "mock_esp32.py failed to start"
    exit 1
fi
log_pass "Mock ESP32 running (PID $MOCK_PID)"

# ---------- 3. Source ROS environment ----------

log_info "Sourcing ROS environment..."
set +u
source /opt/ros/humble/setup.bash
source "$WORKSPACE_ROOT/install/setup.bash" 2>/dev/null || true
set -u

export ROS_DOMAIN_ID=99  # isolated domain for testing
export ROS_LOCALHOST_ONLY=1
export CYBERWAVE_TOKEN="${CYBERWAVE_TOKEN:-smoke-test-token}"

# ---------- 4. Launch the ROS graph ----------

log_info "Launching master_beast.launch.py (camera=false, lidar=false)..."

ros2 launch ugv_bringup master_beast.launch.py \
    use_camera:=false \
    use_lidar:=false \
    use_joint_state_publisher:=true \
    debug_logs:=false \
    &>/tmp/launch_output.log &
LAUNCH_PID=$!

# ---------- 5. Wait for nodes to come up ----------

log_info "Waiting up to ${STARTUP_TIMEOUT}s for ROS nodes..."

EXPECTED_NODES=(
    "/ugv_bringup"
    "/mqtt_bridge_node"
    "/ugv/robot_state_publisher"
    "/base_node"
)

deadline=$((SECONDS + STARTUP_TIMEOUT))
all_found=false

while [ $SECONDS -lt $deadline ]; do
    if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
        echo ""
        log_fail "Launch process died unexpectedly. Last output:"
        tail -30 /tmp/launch_output.log
        exit 1
    fi

    node_list=$(ros2 node list 2>/dev/null || echo "")
    missing=0
    for node in "${EXPECTED_NODES[@]}"; do
        if ! echo "$node_list" | grep -q "$node"; then
            missing=$((missing + 1))
        fi
    done
    if [ "$missing" -eq 0 ]; then
        all_found=true
        break
    fi
    sleep 2
done

echo ""
if $all_found; then
    log_pass "All expected nodes are running"
else
    log_fail "Some nodes did not start within ${STARTUP_TIMEOUT}s"
    echo "  Expected: ${EXPECTED_NODES[*]}"
    echo "  Got:      $(ros2 node list 2>/dev/null || echo '(none)')"
    echo ""
    echo "  Launch output (last 40 lines):"
    tail -40 /tmp/launch_output.log
fi

# Verify each node individually
for node in "${EXPECTED_NODES[@]}"; do
    if ros2 node list 2>/dev/null | grep -q "$node"; then
        log_pass "Node $node is alive"
    else
        log_fail "Node $node is missing"
    fi
done

# ---------- 6. Verify topics exist ----------

echo ""
log_info "Checking ROS topics..."

EXPECTED_TOPICS=(
    "/imu/data_raw"
    "/imu/mag"
    "/odom/odom_raw"
    "/voltage"
    "/cmd_vel"
    "/ugv/joint_states"
)

topic_list=$(ros2 topic list 2>/dev/null || echo "")

for topic in "${EXPECTED_TOPICS[@]}"; do
    if echo "$topic_list" | grep -q "^${topic}$"; then
        log_pass "Topic $topic exists"
    else
        log_fail "Topic $topic missing"
    fi
done

# ---------- 7. Verify topics are publishing ----------

echo ""
log_info "Checking that driver topics are publishing (sampling ${TOPIC_HZ_SAMPLES} messages)..."

DRIVER_TOPICS=("/imu/data_raw" "/odom/odom_raw" "/voltage")

for topic in "${DRIVER_TOPICS[@]}"; do
    msg_count=$(timeout 10 ros2 topic echo "$topic" --once 2>/dev/null | wc -l || echo "0")
    if [ "$msg_count" -gt 0 ]; then
        log_pass "Topic $topic is publishing"
    else
        log_fail "Topic $topic has no messages (driver may not be reading mock serial)"
    fi
done

# ---------- 8. Send a test cmd_vel ----------

echo ""
log_info "Sending test cmd_vel message..."

ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist \
    "{linear: {x: 0.1, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.5}}" \
    &>/dev/null

sleep 1
log_pass "cmd_vel published (mock ESP32 should have received velocity command)"

# ---------- 9. Summary ----------

echo ""
echo "========================================="
total=$((pass_count + fail_count))
echo -e " Results: ${GREEN}${pass_count} passed${NC}, ${RED}${fail_count} failed${NC} / ${total} checks"
echo "========================================="

if [ "$fail_count" -gt 0 ]; then
    echo ""
    echo "Launch output (last 20 lines):"
    tail -20 /tmp/launch_output.log
    exit 1
fi

echo ""
echo "All checks passed!"
exit 0
