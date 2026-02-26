# Custom Files Layer

This layer copies your custom UGV Beast configuration files and scripts into the image.

## Directory Structure

```
50-custom-files/
├── config.yaml                       # Layer configuration (defines file copies)
├── README.md                          # This file
└── files/                             # Source files to copy
    └── ugv_beast/                     # Organize by robot model
        ├── launch/
        │   └── master_beast.launch.py # Copy your launch file here
        ├── ugv_bringup/
        │   └── ugv_integrated_driver.py # Copy your driver here
        ├── setup.py                   # Copy your setup.py here
        ├── ugv_services_install.sh    # Copy your services script here
        └── start_ugv.sh               # Copy your start script here
```

## How to Add Your Files

### Step 1: Copy your source files into the `files/` directory

```bash
# Navigate to the layer directory
cd /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files

# Copy your actual files into the files/ directory structure
# Example:
cp /path/to/your/master_beast.launch.py files/ugv_beast/launch/
cp /path/to/your/ugv_integrated_driver.py files/ugv_beast/ugv_bringup/
cp /path/to/your/setup.py files/ugv_beast/
cp /path/to/your/ugv_services_install.sh files/ugv_beast/
cp /path/to/your/start_ugv.sh files/ugv_beast/
```

### Step 2: Verify files are in place

```bash
ls -lah files/ugv_beast/
ls -lah files/ugv_beast/launch/
ls -lah files/ugv_beast/ugv_bringup/
```

### Step 3: Enable this layer

The layer is already enabled in the main `config.yaml` (as layer `50-custom-files`).

### Step 4: Build the image

When you build the image, these files will automatically be copied to:

| Source | Destination in Image |
|--------|---------------------|
| `files/ugv_beast/launch/master_beast.launch.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py` |
| `files/ugv_beast/ugv_bringup/ugv_integrated_driver.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py` |
| `files/ugv_beast/setup.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py` |
| `files/ugv_beast/ugv_services_install.sh` | `/home/ubuntu/ws/ugv_ws/ugv_services_install.sh` |
| `files/ugv_beast/start_ugv.sh` | `/home/ubuntu/ws/ugv_ws/start_ugv.sh` |

## What Happens During Build

1. **Directories created**: Parent directories are created if they don't exist
2. **Files copied**: Each file is copied to its destination with correct ownership
3. **Permissions set**: Scripts are made executable (0755), config files are 0644
4. **Package rebuilt**: `ugv_bringup` package is rebuilt with the new files
5. **Scripts validated**: Execute permissions are verified

## Adding More Files

To add additional files:

### Option 1: Edit config.yaml

Add more entries to the `files:` section:

```yaml
files:
  # ... existing files ...
  
  # New file
  - src: files/ugv_beast/new_script.sh
    dest: /home/ubuntu/ws/ugv_ws/new_script.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
```

### Option 2: Copy Entire Directories

If you have many files, you can copy entire directories:

```yaml
commands:
  - rsync -av files/ugv_beast/launch/ /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
  - chown -R ubuntu:ubuntu /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
```

## Example: Different Robot Models

You can organize files for different robot models:

```
files/
├── ugv_beast/
│   ├── launch/master_beast.launch.py
│   └── start_ugv_beast.sh
├── ugv_rover/
│   ├── launch/master_rover.launch.py
│   └── start_ugv_rover.sh
└── common/
    └── shared_script.sh
```

Then in `config.yaml`, selectively copy based on model:

```yaml
files:
  # Common files
  - src: files/common/shared_script.sh
    dest: /home/ubuntu/ws/ugv_ws/shared_script.sh
    
  # Model-specific (Beast)
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master.launch.py
```

## Testing Locally First

Before building the full image, test your files on the current system:

```bash
# Copy files manually
cp files/ugv_beast/launch/master_beast.launch.py \
   /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/

# Rebuild package
cd /home/ubuntu/ws/ugv_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
colcon build --packages-select ugv_bringup --symlink-install

# Test launch
export UGV_MODEL=ugv_beast
ros2 launch ugv_bringup master_beast.launch.py
```

If this works locally, it will work in the image!

## Troubleshooting

### Files Not Appearing in Image

1. Check source files exist:
   ```bash
   ls -lah files/ugv_beast/
   ```

2. Check `config.yaml` syntax (YAML is indent-sensitive!)

3. Check layer is enabled in main `config.yaml`:
   ```yaml
   layers:
     - 50-custom-files  # Must be listed
   ```

### Permission Denied

Make sure executable files have mode `0755`:

```yaml
mode: "0755"  # Executable
# vs
mode: "0644"  # Regular file
```

### File Overwrites Not Working

If files aren't being updated, check:

1. Source file timestamp (is it newer?)
2. Destination permissions
3. Add backup option:
   ```yaml
   backup: true  # Creates .bak before overwriting
   ```

## Quick Setup Script

Run this to verify the layer is ready:

```bash
#!/bin/bash
cd /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files

echo "Checking custom files layer..."

# Check config exists
if [ ! -f "config.yaml" ]; then
    echo "❌ config.yaml missing!"
    exit 1
fi

# Check required source files
FILES=(
    "files/ugv_beast/launch/master_beast.launch.py"
    "files/ugv_beast/ugv_bringup/ugv_integrated_driver.py"
    "files/ugv_beast/setup.py"
    "files/ugv_beast/ugv_services_install.sh"
    "files/ugv_beast/start_ugv.sh"
)

MISSING=0
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Missing: $file"
        MISSING=1
    else
        echo "✅ Found: $file"
    fi
done

if [ $MISSING -eq 1 ]; then
    echo ""
    echo "⚠️  Some files are missing!"
    echo "Copy your files to the locations shown above."
    exit 1
fi

echo ""
echo "✅ All source files present!"
echo "Ready to build image."
```

## Next Steps

1. **Copy your files** into the `files/ugv_beast/` directory
2. **Test locally** (optional but recommended)
3. **Build the image** - files will be included automatically
4. **Flash to SD card** and test on hardware

For more details, see the main [CUSTOM_FILES_GUIDE.md](/home/ubuntu/ws/ugv-rpi-image/CUSTOM_FILES_GUIDE.md).
