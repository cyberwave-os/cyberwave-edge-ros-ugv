#!/bin/bash
# Quick Setup Script for Adding Custom Files to UGV RPI Image
# This script helps you copy your custom files into the rpi-image-gen structure

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 UGV Custom Files Setup Helper"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LAYER_DIR="/home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files"

# Check if layer exists
if [ ! -d "$LAYER_DIR" ]; then
    echo "❌ Custom files layer not found at: $LAYER_DIR"
    exit 1
fi

cd "$LAYER_DIR"

echo "📁 Layer location: $LAYER_DIR"
echo ""

# Instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 How to Add Your Custom Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Step 1: Copy your files to the source directory"
echo "----------------------------------------"
echo ""
echo "Replace the placeholder files with your actual files:"
echo ""
echo "  cp /path/to/your/master_beast.launch.py \\"
echo "     $LAYER_DIR/files/ugv_beast/launch/"
echo ""
echo "  cp /path/to/your/ugv_integrated_driver.py \\"
echo "     $LAYER_DIR/files/ugv_beast/ugv_bringup/"
echo ""
echo "  cp /path/to/your/setup.py \\"
echo "     $LAYER_DIR/files/ugv_beast/"
echo ""
echo "  cp /path/to/your/ugv_services_install.sh \\"
echo "     $LAYER_DIR/files/ugv_beast/"
echo ""
echo "  cp /path/to/your/start_ugv.sh \\"
echo "     $LAYER_DIR/files/ugv_beast/"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Step 2: Verify your files"
echo "-------------------------"
echo ""
echo "  bash $LAYER_DIR/validate.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Step 3: Build the image"
echo "-----------------------"
echo ""
echo "  cd ~/rpi-image-gen"
echo "  sudo ./build.sh /home/ubuntu/ws/ugv-rpi-image/config.yaml"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check current status
echo "📊 Current Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

FILES=(
    "files/ugv_beast/launch/master_beast.launch.py"
    "files/ugv_beast/ugv_bringup/ugv_integrated_driver.py"
    "files/ugv_beast/setup.py"
    "files/ugv_beast/ugv_services_install.sh"
    "files/ugv_beast/start_ugv.sh"
)

READY=0
PLACEHOLDER=0
MISSING=0

for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        MISSING=1
    elif grep -q "PLACEHOLDER" "$file" 2>/dev/null; then
        SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
        echo "⚠️  Placeholder: $file (${SIZE} bytes) - REPLACE ME!"
        PLACEHOLDER=1
    else
        SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
        echo "✅ Ready: $file (${SIZE} bytes)"
        READY=1
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $MISSING -gt 0 ]; then
    echo "Status: ❌ Files missing - see above"
elif [ $PLACEHOLDER -gt 0 ]; then
    echo "Status: ⚠️  Placeholder files - replace with your actual files"
else
    echo "Status: ✅ All custom files ready!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 More Information:"
echo "  • Layer README:  $LAYER_DIR/README.md"
echo "  • Full Guide:    /home/ubuntu/ws/ugv-rpi-image/CUSTOM_FILES_GUIDE.md"
echo "  • Validate:      bash $LAYER_DIR/validate.sh"
echo ""

exit 0
