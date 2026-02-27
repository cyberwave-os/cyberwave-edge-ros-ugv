#!/bin/bash
# =============================================================================
# UGV Beast Docker Integration Test
# =============================================================================
#
# Builds the Docker image and runs the smoke test that verifies the full
# ROS 2 graph starts correctly against a mock ESP32 serial emulator.
#
# Steps:
#   1. Builds the root Docker image
#   2. Runs the smoke test inside the container (mock ESP32 + ROS launch)
#   3. Optionally builds the mqtt_bridge Docker image
#
# The smoke test verifies:
#   - Virtual serial port (socat) creation
#   - Mock ESP32 emulator produces T:1001 telemetry at 20 Hz
#   - All expected ROS nodes start (ugv_bringup, mqtt_bridge, etc.)
#   - All expected ROS topics exist and are publishing
#   - cmd_vel commands reach the mock ESP32
#
# Usage:
#   cd cyberwave-edge-nodes/cyberwave-edge-ros-ugv && bash test-ugv.sh
#   bash test-ugv.sh --skip-build    # reuse existing image
#   bash test-ugv.sh --mqtt-bridge   # also build mqtt_bridge Dockerfile
#
# Prerequisites:
#   - Docker installed and running
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="cyberwave-edge-ros-ugv"
SKIP_BUILD=false
BUILD_MQTT_BRIDGE=false

for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --mqtt-bridge)
            BUILD_MQTT_BRIDGE=true
            shift
            ;;
        --help)
            echo "Usage: bash test-ugv.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build     Reuse existing Docker image (skip docker build)"
            echo "  --mqtt-bridge    Also build the mqtt_bridge Dockerfile"
            echo "  --help           Show this help"
            exit 0
            ;;
    esac
done

# =============================================================================
# Step 1: Build Docker image
# =============================================================================
echo ""
echo "=========================================="
echo " Step 1: Building Docker image"
echo "=========================================="

cd "$SCRIPT_DIR"

if [ "$SKIP_BUILD" = true ]; then
    if docker image inspect "$IMAGE_NAME" &>/dev/null; then
        echo "Skipping build — reusing existing image: $IMAGE_NAME"
    else
        echo "ERROR: --skip-build specified but image '$IMAGE_NAME' not found"
        echo "Run without --skip-build first."
        exit 1
    fi
else
    echo "Building $IMAGE_NAME (this takes 10-15 min on first build)..."
    docker build -t "$IMAGE_NAME" .
    echo "  ✅ Docker image built successfully"
fi

# =============================================================================
# Step 2: Smoke test ROS graph with mock ESP32
# =============================================================================
echo ""
echo "=========================================="
echo " Step 2: Smoke test — ROS graph with mock ESP32"
echo "=========================================="

docker run --rm --privileged \
    -v "$SCRIPT_DIR/tests:/home/ws/tests" \
    -e CYBERWAVE_API_KEY=smoke-test-token \
    -e CYBERWAVE_TWIN_UUID=00000000-0000-0000-0000-smoke-test \
    "$IMAGE_NAME" \
    bash /home/ws/tests/smoke_test.sh

echo "  ✅ Smoke test passed"

# =============================================================================
# Step 3: Build mqtt_bridge Dockerfile (optional)
# =============================================================================
if [ "$BUILD_MQTT_BRIDGE" = true ]; then
    echo ""
    echo "=========================================="
    echo " Step 3: Building mqtt_bridge Dockerfile"
    echo "=========================================="

    cd "$SCRIPT_DIR/mqtt_bridge"
    docker build -f docker-conf/Dockerfile -t "${IMAGE_NAME}-mqtt" .
    echo "  ✅ mqtt_bridge Dockerfile built successfully"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=========================================="
echo " ✅ All UGV tests passed!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Docker image built: $IMAGE_NAME"
echo "  - ROS graph smoke test passed (18 checks)"
echo "    - Mock ESP32 serial emulator verified"
echo "    - All ROS nodes started successfully"
echo "    - All topics publishing"
echo "    - cmd_vel → mock ESP32 round-trip verified"
if [ "$BUILD_MQTT_BRIDGE" = true ]; then
    echo "  - mqtt_bridge Dockerfile built: ${IMAGE_NAME}-mqtt"
fi
echo ""
