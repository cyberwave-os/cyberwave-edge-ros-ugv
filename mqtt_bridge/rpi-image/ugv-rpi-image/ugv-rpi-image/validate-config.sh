#!/bin/bash

# Validation Script for UGV RPI Image Configuration
# This script checks that all required files are present before building

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  UGV Raspberry Pi Image Configuration Validator              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_ROOT="$SCRIPT_DIR"

ERRORS=0
WARNINGS=0

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$IMAGE_ROOT/$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "  Missing: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check if directory exists
check_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$IMAGE_ROOT/$dir" ]; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "  Missing: $dir"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check if file is executable
check_executable() {
    local file=$1
    local description=$2
    
    if [ -f "$IMAGE_ROOT/$file" ] && [ -x "$IMAGE_ROOT/$file" ]; then
        echo -e "${GREEN}✓${NC} $description (executable)"
        return 0
    elif [ -f "$IMAGE_ROOT/$file" ]; then
        echo -e "${YELLOW}⚠${NC} $description (not executable)"
        echo -e "  Run: chmod +x $file"
        WARNINGS=$((WARNINGS + 1))
        return 1
    else
        echo -e "${RED}✗${NC} $description"
        echo -e "  Missing: $file"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "Checking main configuration files..."
echo "────────────────────────────────────────────────────────────────"
check_file "config.yaml" "Main configuration file"
check_file "layers/50-custom-files/config.yaml" "Custom files layer configuration"
echo ""

echo "Checking layer structure..."
echo "────────────────────────────────────────────────────────────────"
check_dir "layers/50-custom-files" "Custom files layer directory"
check_dir "layers/50-custom-files/files" "Custom files source directory"
check_dir "scripts" "Build scripts directory"
echo ""

echo "Checking UGV Beast files..."
echo "────────────────────────────────────────────────────────────────"
check_dir "layers/50-custom-files/files/ugv_beast" "UGV Beast directory"
check_file "layers/50-custom-files/files/ugv_beast/launch/master_beast.launch.py" "Master launch file"
check_file "layers/50-custom-files/files/ugv_beast/ugv_bringup/ugv_integrated_driver.py" "UGV integrated driver"
check_file "layers/50-custom-files/files/ugv_beast/setup.py" "UGV setup.py"
check_executable "layers/50-custom-files/files/ugv_beast/ugv_services_install.sh" "Services install script"
check_executable "layers/50-custom-files/files/ugv_beast/start_ugv.sh" "Start UGV script"
echo ""

echo "Checking MQTT Bridge package files..."
echo "────────────────────────────────────────────────────────────────"
check_dir "layers/50-custom-files/files/mqtt_bridge" "MQTT Bridge directory"
check_file "layers/50-custom-files/files/mqtt_bridge/__init__.py" "MQTT Bridge __init__.py"
check_file "layers/50-custom-files/files/mqtt_bridge/mqtt_bridge_node.py" "MQTT Bridge node"
check_file "layers/50-custom-files/files/mqtt_bridge/cyberwave_mqtt_adapter.py" "Cyberwave MQTT adapter"
check_file "layers/50-custom-files/files/mqtt_bridge/command_handler.py" "Command handler"
check_file "layers/50-custom-files/files/mqtt_bridge/health.py" "Health monitor"
check_file "layers/50-custom-files/files/mqtt_bridge/logger_shim.py" "Logger shim"
check_file "layers/50-custom-files/files/mqtt_bridge/mapping.py" "Mapping module"
check_file "layers/50-custom-files/files/mqtt_bridge/telemetry.py" "Telemetry module"
echo ""

echo "Checking MQTT Bridge plugins..."
echo "────────────────────────────────────────────────────────────────"
check_dir "layers/50-custom-files/files/mqtt_bridge/plugins" "MQTT Bridge plugins directory"
check_file "layers/50-custom-files/files/mqtt_bridge/plugins/__init__.py" "Plugins __init__.py"
check_file "layers/50-custom-files/files/mqtt_bridge/plugins/internal_odometry.py" "Internal odometry plugin"
check_file "layers/50-custom-files/files/mqtt_bridge/plugins/navigation_bridge.py" "Navigation bridge plugin"
check_file "layers/50-custom-files/files/mqtt_bridge/plugins/ros_camera.py" "ROS camera plugin"
check_file "layers/50-custom-files/files/mqtt_bridge/plugins/ugv_beast_command_handler.py" "UGV Beast command handler"
echo ""

echo "Checking for Python cache files (should be cleaned)..."
echo "────────────────────────────────────────────────────────────────"
PYCACHE_FOUND=$(find "$IMAGE_ROOT/layers/50-custom-files/files" -name "__pycache__" -o -name "*.pyc" 2>/dev/null | wc -l)
if [ $PYCACHE_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No Python cache files found (good!)"
else
    echo -e "${YELLOW}⚠${NC} Found $PYCACHE_FOUND Python cache files/directories"
    echo -e "  These will be included in the image (not critical but unnecessary)"
    echo -e "  Run: find layers/50-custom-files/files -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "Checking build scripts..."
echo "────────────────────────────────────────────────────────────────"
check_file "scripts/apply-fixes.sh" "Apply fixes script"
check_file "scripts/build-workspace.sh" "Build workspace script"
check_file "scripts/install-python.sh" "Install Python dependencies script"
echo ""

echo "Checking documentation..."
echo "────────────────────────────────────────────────────────────────"
check_file "README.md" "README"
check_file "BUILD_GUIDE.md" "Build guide (NEW)"
check_file "BUILD_MACHINE_WORKFLOW.md" "Build machine workflow"
check_file "CUSTOM_FILES_GUIDE.md" "Custom files guide"
check_file "QUICK_START_CUSTOM_FILES.md" "Quick start guide"
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    VALIDATION SUMMARY                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED!${NC}"
    echo -e "${GREEN}Your image configuration is ready to build!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Copy this directory to your Build Machine"
    echo "2. Install rpi-image-gen: git clone https://github.com/raspberrypi/rpi-image-gen.git"
    echo "3. Build: sudo ./build.sh $(pwd)/config.yaml"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ VALIDATION PASSED WITH WARNINGS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo ""
    echo "You can proceed with the build, but consider fixing the warnings."
    echo ""
    exit 0
else
    echo -e "${RED}✗ VALIDATION FAILED${NC}"
    echo -e "${RED}Errors: $ERRORS${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    fi
    echo ""
    echo "Please fix the errors before building the image."
    echo ""
    exit 1
fi
