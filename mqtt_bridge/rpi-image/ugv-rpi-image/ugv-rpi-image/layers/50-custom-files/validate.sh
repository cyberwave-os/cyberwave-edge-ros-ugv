#!/bin/bash
# Validate Custom Files Layer
# Checks that all required source files are present before building image

set -e

LAYER_DIR="/home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files"
cd "$LAYER_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Validating Custom Files Layer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check config.yaml exists
echo "Checking config.yaml..."
if [ ! -f "config.yaml" ]; then
    echo "❌ config.yaml missing!"
    exit 1
fi
echo "✅ config.yaml found"
echo ""

# Check required source files
echo "Checking source files..."
FILES=(
    "files/ugv_beast/launch/master_beast.launch.py"
    "files/ugv_beast/ugv_bringup/ugv_integrated_driver.py"
    "files/ugv_beast/setup.py"
    "files/ugv_beast/ugv_services_install.sh"
    "files/ugv_beast/start_ugv.sh"
)

MISSING=0
PLACEHOLDER=0

for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        MISSING=1
    else
        # Check if file is a placeholder
        if grep -q "PLACEHOLDER" "$file" 2>/dev/null; then
            echo "⚠️  Placeholder: $file (replace with your actual file)"
            PLACEHOLDER=1
        else
            # Show file size
            SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "?")
            echo "✅ Found: $file (${SIZE} bytes)"
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $MISSING -eq 1 ]; then
    echo "❌ VALIDATION FAILED - Missing files!"
    echo ""
    echo "Copy your files to the locations shown above."
    echo "Example:"
    echo "  cp /path/to/your/master_beast.launch.py files/ugv_beast/launch/"
    exit 1
fi

if [ $PLACEHOLDER -eq 1 ]; then
    echo "⚠️  WARNING - Placeholder files detected!"
    echo ""
    echo "Replace placeholder files with your actual files."
    echo "Placeholder files are provided as examples only."
    echo ""
    echo "You can proceed with the build, but the image may not work correctly."
    exit 2  # Warning, but not fatal
fi

echo "✅ VALIDATION PASSED - All source files present!"
echo ""
echo "Ready to build image with custom files."
echo ""
echo "File mappings (source → destination in image):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for file in "${FILES[@]}"; do
    echo "  $file"
done
echo "    ↓"
echo "  /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/..."
echo ""

exit 0
