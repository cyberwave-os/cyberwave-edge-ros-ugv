#!/bin/bash
################################################################################
# Python Packages Installation Script
# Installs all Python dependencies for UGV
################################################################################

set -e

echo "📦 Installing Python packages for UGV..."

WORKSPACE="/home/ubuntu/ws/ugv_ws"

# Install from requirements.txt
if [ -f "$WORKSPACE/requirements.txt" ]; then
    echo "  Installing from requirements.txt..."
    python3 -m pip install -r "$WORKSPACE/requirements.txt" --break-system-packages
fi

# Install additional UGV-specific packages
echo "  Installing UGV-specific packages..."
pip3 install --break-system-packages \
    pyserial \
    flask \
    mediapipe \
    requests \
    aiortc \
    aioice \
    av \
    cyberwave

echo "✅ Python packages installed successfully!"
