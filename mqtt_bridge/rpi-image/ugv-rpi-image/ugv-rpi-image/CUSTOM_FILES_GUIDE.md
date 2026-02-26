# Including Local Files in rpi-image-gen

## Overview

To include custom files in your image, you use the `files:` section in your layer configuration. This copies files from your build machine into the final image at specific locations.

## Directory Structure for Custom Files

Create a new layer for your custom files:

```
ugv-rpi-image/
├── layers/
│   └── 50-custom-files/          # New layer for custom files
│       ├── config.yaml            # Layer configuration
│       └── files/                 # Source files to copy
│           ├── ugv_beast/         # Organize by category
│           │   ├── launch/
│           │   │   └── master_beast.launch.py
│           │   ├── ugv_bringup/
│           │   │   └── ugv_integrated_driver.py
│           │   ├── setup.py
│           │   ├── ugv_services_install.sh
│           │   └── start_ugv.sh
│           ├── config/
│           │   └── robot_config.yaml
│           └── scripts/
│               └── custom_script.sh
```

## Layer Configuration (layers/50-custom-files/config.yaml)

```yaml
name: "custom-files"
description: "Custom UGV configuration files and scripts"

# Copy individual files to specific locations
files:
  # UGV Beast launch file
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # UGV integrated driver
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Setup.py
  - src: files/ugv_beast/setup.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # UGV services install script
  - src: files/ugv_beast/ugv_services_install.sh
    dest: /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
    mode: "0755"  # Executable
    owner: ubuntu
    group: ubuntu
    
  # Start UGV script
  - src: files/ugv_beast/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"  # Executable
    owner: ubuntu
    group: ubuntu

# Optional: Run commands after copying files
user_commands:
  # Make scripts executable
  - chmod +x /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
  - chmod +x /home/ubuntu/ws/ugv_ws/start_ugv.sh
  
  # Optional: Run installation script
  # - cd /home/ubuntu/ws/ugv_ws && bash ugv_services_install.sh
```

## Alternative: Copy Entire Directories

If you want to copy entire directory structures:

```yaml
name: "custom-files"
description: "Custom UGV configuration files and scripts"

# Method 1: Copy entire directory tree
directories:
  - src: files/ugv_beast/
    dest: /home/ubuntu/ws/ugv_custom/
    owner: ubuntu
    group: ubuntu
    recursive: true

# Method 2: Use rsync pattern
commands:
  - rsync -av files/ugv_beast/ /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/
  
# Method 3: Use cp with directory structure preserved
commands:
  - cp -r files/ugv_beast/launch/* /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
  - cp -r files/ugv_beast/ugv_bringup/* /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/
```

## Practical Example: Your Use Case

### Step 1: Organize Your Source Files

```bash
cd /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files

# Create directory structure matching your needs
mkdir -p ugv_beast/{launch,ugv_bringup,scripts}

# Place your files here:
# files/ugv_beast/launch/master_beast.launch.py
# files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
# files/ugv_beast/setup.py
# files/ugv_beast/ugv_services_install.sh
# files/ugv_beast/start_ugv.sh
```

### Step 2: Create config.yaml

```yaml
name: "custom-ugv-files"
description: "UGV Beast custom configuration and launch files"

files:
  # Launch files
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Python modules
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/setup.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Executable scripts
  - src: files/ugv_beast/ugv_services_install.sh
    dest: /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu

# Rebuild package after copying modified files
user_commands:
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - source install/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
```

### Step 3: Update Main config.yaml

```yaml
# In your main config.yaml, add the new layer
layers:
  - 00-base
  - 10-ros2-jazzy
  - 20-ugv-system
  - 30-ugv-workspace
  - 40-ugv-apps
  - 50-custom-files    # Add this line
```

## Advanced Patterns

### Pattern 1: Template Files with Variables

```yaml
files:
  - src: files/config.template.yaml
    dest: /home/ubuntu/ws/config.yaml
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    template: true  # Enable templating
    variables:
      ROBOT_NAME: "ugv-beast-01"
      ROBOT_IP: "192.168.1.100"
      UGV_MODEL: "ugv_beast"
```

Then in your template file:
```yaml
robot:
  name: {{ ROBOT_NAME }}
  ip: {{ ROBOT_IP }}
  model: {{ UGV_MODEL }}
```

### Pattern 2: Copy with Backup

```yaml
files:
  - src: files/custom_config.yaml
    dest: /home/ubuntu/ws/config.yaml
    backup: true  # Creates .bak before overwriting
    mode: "0644"
```

### Pattern 3: Conditional Copying

```yaml
files:
  - src: files/ugv_beast/config.yaml
    dest: /home/ubuntu/ws/config.yaml
    condition: "{{ UGV_MODEL == 'ugv_beast' }}"
    
  - src: files/ugv_rover/config.yaml
    dest: /home/ubuntu/ws/config.yaml
    condition: "{{ UGV_MODEL == 'ugv_rover' }}"
```

### Pattern 4: Copy Multiple Files at Once

```yaml
# Copy all files matching pattern
commands:
  - find files/ugv_beast/launch/ -name "*.launch.py" -exec cp {} /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/ \;
  
# Or use rsync for better control
commands:
  - rsync -av --chown=ubuntu:ubuntu files/ugv_beast/ /home/ubuntu/ws/ugv_ws/custom/
```

## File Permissions Guide

### Common Permission Modes

```yaml
mode: "0644"  # Read/write owner, read others (config files)
mode: "0755"  # Executable scripts
mode: "0600"  # Secrets (read/write owner only)
mode: "0664"  # Read/write owner and group
```

### Setting Ownership

```yaml
owner: ubuntu      # User owner
group: ubuntu      # Group owner
```

## Complete Example: Your Exact Use Case

Create this file structure:

```bash
cd /home/ubuntu/ws/ugv-rpi-image

# Create the directories
mkdir -p layers/50-custom-files/files/ugv_beast/{launch,ugv_bringup}

# Copy your files to the source location
# (These would be your actual custom files)
cp /path/to/your/master_beast.launch.py \
   layers/50-custom-files/files/ugv_beast/launch/

cp /path/to/your/ugv_integrated_driver.py \
   layers/50-custom-files/files/ugv_beast/ugv_bringup/

cp /path/to/your/setup.py \
   layers/50-custom-files/files/ugv_beast/

cp /path/to/your/ugv_services_install.sh \
   layers/50-custom-files/files/ugv_beast/

cp /path/to/your/start_ugv.sh \
   layers/50-custom-files/files/ugv_beast/
```

Then create the configuration:

```yaml
# layers/50-custom-files/config.yaml
name: "custom-ugv-files"
description: "UGV Beast custom files and scripts"

files:
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/setup.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/ugv_services_install.sh
    dest: /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu

# Rebuild the package with modified files
user_commands:
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - source install/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
  - chmod +x /home/ubuntu/ws/ugv_ws/*.sh
```

## Testing Before Building Image

Before building the full image, test your file copying locally:

```bash
# Copy files to your current Pi
cd /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files

# Test copy commands
cp files/ugv_beast/launch/master_beast.launch.py \
   /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/

# Rebuild package
cd /home/ubuntu/ws/ugv_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
colcon build --packages-select ugv_bringup --symlink-install

# Test launch
ros2 launch ugv_bringup master_beast.launch.py
```

If this works, then your rpi-image-gen config is correct!

## Common Pitfalls and Solutions

### Pitfall 1: Source Paths

❌ **Wrong:**
```yaml
files:
  - src: /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/script.sh
```

✅ **Correct:**
```yaml
files:
  - src: files/script.sh  # Relative to layer directory
```

### Pitfall 2: Missing Parent Directories

If destination directory doesn't exist:

```yaml
commands:
  # Create parent directory first
  - mkdir -p /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch
  
files:
  - src: files/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
```

### Pitfall 3: File Permissions

For scripts, always set executable:

```yaml
files:
  - src: files/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"  # Important! Makes it executable
```

### Pitfall 4: Overwriting Source Files Before Build

If you copy files that modify ROS packages, rebuild them:

```yaml
user_commands:
  # Copy files first (happens via files: section above)
  # Then rebuild affected packages
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - source install/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
```

## Complete Working Example

Let me create a complete example for your use case:

```yaml
# layers/50-custom-files/config.yaml
name: "custom-ugv-files"
description: "Custom UGV Beast files and configuration"

# Create necessary directories first
commands:
  - mkdir -p /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch
  - mkdir -p /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup

# Copy files
files:
  # Launch file
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Python driver
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Package setup
  - src: files/ugv_beast/setup.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  # Service installation script
  - src: files/ugv_beast/ugv_services_install.sh
    dest: /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # Start script
  - src: files/ugv_beast/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  # Robot configuration (example)
  - src: files/config/robot_config.yaml
    dest: /etc/ugv/robot_config.yaml
    mode: "0644"
    owner: root
    group: root

# Post-copy actions
user_commands:
  # Rebuild ugv_bringup package with new files
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - source install/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
  
  # Run services installation
  - bash /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
  
  # Create systemd service (if needed)
  # - cp files/systemd/ugv.service /etc/systemd/system/
  # - systemctl enable ugv.service
```

## Multiple Variants (Different Robot Models)

If you have different files for different robot models:

```yaml
# layers/50-custom-files/config.yaml
name: "custom-files"
description: "Model-specific files"

files:
  # Common files (for all models)
  - src: files/common/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu

# Model-specific files
variants:
  ugv_beast:
    files:
      - src: files/ugv_beast/master_beast.launch.py
        dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master.launch.py
        
  ugv_rover:
    files:
      - src: files/ugv_rover/master_rover.launch.py
        dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master.launch.py
```

Then build different images:
```bash
# Build UGV Beast image
./build.sh config.yaml --variant ugv_beast

# Build UGV Rover image
./build.sh config.yaml --variant ugv_rover
```

## Advanced: Using Archives

For large file collections:

```yaml
archives:
  # Extract tar/zip archives
  - src: files/ugv_meshes.tar.gz
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_description/meshes/
    owner: ubuntu
    group: ubuntu
    extract: true
```

## Best Practices

### 1. Organize by Purpose

```
files/
├── launch/          # Launch files
├── config/          # Configuration files
├── scripts/         # Shell scripts
├── python/          # Python modules
└── systemd/         # Systemd services
```

### 2. Version Control Everything

```bash
cd /home/ubuntu/ws/ugv-rpi-image
git init
git add .
git commit -m "Initial UGV image configuration"
git tag v1.0.0
```

### 3. Document What Each File Does

```yaml
files:
  - src: files/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    description: "Main startup script for UGV system"  # Add descriptions
    mode: "0755"
```

### 4. Validate Before Building

Create a validation script:

```bash
#!/bin/bash
# validate.sh - Check all source files exist

echo "Validating source files..."

FILES=(
  "layers/50-custom-files/files/ugv_beast/launch/master_beast.launch.py"
  "layers/50-custom-files/files/ugv_beast/ugv_services_install.sh"
  # ... add all files
)

for file in "${FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "❌ Missing: $file"
    exit 1
  fi
done

echo "✅ All source files found!"
```

## Update Main Config

Add the custom files layer to your main configuration:

```yaml
# config.yaml (main file)
layers:
  - 00-base                # Base system
  - 10-ros2-jazzy          # ROS 2 Jazzy
  - 20-ugv-system          # UGV hardware config
  - 30-ugv-workspace       # Build ROS workspace
  - 40-ugv-apps            # UGV applications
  - 50-custom-files        # YOUR CUSTOM FILES ← Add this
```

## Quick Command to Set Everything Up

```bash
#!/bin/bash
# setup-custom-layer.sh

LAYER_DIR="/home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files"

# Create structure
mkdir -p "$LAYER_DIR/files/ugv_beast"/{launch,ugv_bringup,scripts}
mkdir -p "$LAYER_DIR/files/config"

# Create config.yaml
cat > "$LAYER_DIR/config.yaml" << 'EOF'
name: "custom-ugv-files"
description: "Custom UGV files"

files:
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/setup.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
    mode: "0644"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/ugv_services_install.sh
    dest: /home/ubuntu/ws/ugv_ws/ugv_services_install.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu
    
  - src: files/ugv_beast/start_ugv.sh
    dest: /home/ubuntu/ws/ugv_ws/start_ugv.sh
    mode: "0755"
    owner: ubuntu
    group: ubuntu

user_commands:
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - source install/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
EOF

echo "✅ Custom layer created!"
echo "Now copy your files to: $LAYER_DIR/files/ugv_beast/"
```

## Summary

**To include custom files in rpi-image-gen:**

1. **Create layer directory:** `layers/50-custom-files/files/`
2. **Place source files** in `files/` subdirectory
3. **Define file mappings** in `config.yaml` using `files:` section
4. **Set permissions** with `mode:`, `owner:`, `group:`
5. **Add layer** to main `config.yaml`
6. **Build image** - files automatically copied!

**Your files go from:**
```
layers/50-custom-files/files/ugv_beast/script.sh  (source)
    ↓ (during image build)
/home/ubuntu/ws/ugv_ws/script.sh  (in final image)
```

Simple as that! 🚀
