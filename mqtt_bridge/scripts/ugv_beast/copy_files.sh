#!/bin/bash

# Script to copy UGV Beast files to their destination locations
# Created: 2026-02-05
# Usage: Run this script from /home/ws/ugv_ws directory

set -e  # Exit on error

echo "Starting file copy process..."

# Get the script's directory relative to where it's called from
SCRIPT_DIR="src/mqtt_bridge/scripts/ugv_beast"

# Verify we're running from the correct directory
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "ERROR: This script must be run from /home/ws/ugv_ws directory"
    echo "Current directory: $(pwd)"
    echo "Expected to find: $SCRIPT_DIR"
    exit 1
fi

# Define source and destination paths (all relative to workspace root)
declare -A FILES=(
    ["${SCRIPT_DIR}/ugv_bringup/launch/master_beast.launch.py"]="src/ugv_main/ugv_bringup/launch/"
    ["${SCRIPT_DIR}/ugv_bringup/ugv_bringup/ugv_integrated_driver.py"]="src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py"
    ["${SCRIPT_DIR}/ugv_bringup/setup.py"]="src/ugv_main/ugv_bringup/setup.py"
    ["${SCRIPT_DIR}/ugv_run.sh"]="ugv_run.sh"
    ["${SCRIPT_DIR}/ugv_services_install.sh"]="ugv_services_install.sh"
)

# Function to copy file and create destination directory if needed
copy_file() {
    local src="$1"
    local dest="$2"
    
    # Check if source file exists
    if [ ! -f "$src" ]; then
        echo "ERROR: Source file not found: $src"
        return 1
    fi
    
    # If destination is a directory, create it if it doesn't exist
    if [[ "$dest" == */ ]]; then
        mkdir -p "$dest"
        echo "Copying: $src -> $dest"
        cp -v "$src" "$dest"
    else
        # Create parent directory if it doesn't exist
        local dest_dir=$(dirname "$dest")
        mkdir -p "$dest_dir"
        echo "Copying: $src -> $dest"
        cp -v "$src" "$dest"
    fi
}

# Copy each file
for src in "${!FILES[@]}"; do
    dest="${FILES[$src]}"
    if copy_file "$src" "$dest"; then
        echo "✓ Successfully copied: $(basename $src)"
    else
        echo "✗ Failed to copy: $(basename $src)"
        exit 1
    fi
    echo ""
done

echo "All files copied successfully!"
