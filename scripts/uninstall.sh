#!/bin/bash

set -e

echo "======================================="
echo "Cyberwave Edge ROS2 - Uninstallation"
echo "======================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Configuration
INSTALL_DIR="/opt/cyberwave-edge-ros"
SERVICE_FILE="cyberwave-edge-ros.service"

# Stop and disable service
if systemctl is-active --quiet $SERVICE_FILE; then
    echo "Stopping service..."
    systemctl stop $SERVICE_FILE
fi

if systemctl is-enabled --quiet $SERVICE_FILE; then
    echo "Disabling service..."
    systemctl disable $SERVICE_FILE
fi

# Remove systemd service file
if [ -f "/etc/systemd/system/$SERVICE_FILE" ]; then
    echo "Removing systemd service file..."
    rm /etc/systemd/system/$SERVICE_FILE
    systemctl daemon-reload
fi

# Ask about removing installation directory
echo
read -p "Remove installation directory $INSTALL_DIR? This will delete all configuration files. (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing installation directory..."
    rm -rf $INSTALL_DIR
else
    echo "Keeping installation directory at $INSTALL_DIR"
fi

# Ask about removing service user
echo
read -p "Remove service user 'cyberwave'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing service user..."
    userdel cyberwave 2>/dev/null || true
else
    echo "Keeping service user 'cyberwave'"
fi

echo
echo "====================================="
echo "Uninstallation Complete!"
echo "====================================="
echo
