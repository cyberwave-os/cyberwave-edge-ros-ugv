# Quick Reference: Adding Custom Files to UGV RPI Image

## TL;DR

You want to include custom files (like launch files, scripts, configs) in your rpi-image-gen image? Here's how:

### The Simple 3-Step Process

```bash
# 1. Copy your files to the source location
cp your-file.py /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/ugv_beast/

# 2. Verify they're ready
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/validate.sh

# 3. Build the image (files are automatically included)
cd ~/rpi-image-gen && sudo ./build.sh /home/ubuntu/ws/ugv-rpi-image/config.yaml
```

---

## Your Example Use Case

You want to copy these files:

| Your Source File | Destination in Final Image |
|------------------|----------------------------|
| `scripts/ugv_beast/ugv_bringup/launch/master_beast.launch.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py` |
| `scripts/ugv_beast/ugv_bringup/ugv_bringup/ugv_integrated_driver.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py` |
| `scripts/ugv_beast/ugv_bringup/setup.py` | `/home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py` |
| `scripts/ugv_beast/ugv_services_install.sh` | `/home/ubuntu/ws/ugv_ws/ugv_services_install.sh` |
| `scripts/ugv_beast/start_ugv.sh` | `/home/ubuntu/ws/ugv_ws/start_ugv.sh` |

### Solution: Use Layer 50-custom-files

**Layer structure already created for you:**

```
/home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/
├── config.yaml                   ← File mappings defined here
├── files/                        ← Put your SOURCE files here
│   └── ugv_beast/
│       ├── launch/
│       │   └── master_beast.launch.py
│       ├── ugv_bringup/
│       │   └── ugv_integrated_driver.py
│       ├── setup.py
│       ├── ugv_services_install.sh
│       └── start_ugv.sh
├── README.md                     ← Detailed documentation
├── setup-helper.sh               ← Status checker
└── validate.sh                   ← Validation script
```

### How It Works

1. **You put files in:** `layers/50-custom-files/files/ugv_beast/`
2. **During image build:** rpi-image-gen copies them to the destination paths
3. **Result:** Final image has your files in the right places

### config.yaml Explanation

The `config.yaml` in the layer defines the file mappings:

```yaml
files:
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
    mode: "0644"    # File permissions
    owner: ubuntu   # File owner
    group: ubuntu   # File group
```

This says: "Copy `files/ugv_beast/launch/master_beast.launch.py` (relative to layer dir) to `/home/ubuntu/ws/ugv_ws/...` in the final image."

---

## Step-by-Step Instructions

### Step 1: Copy Your Files

```bash
# Navigate to the custom files directory
cd /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/ugv_beast

# Copy your files here
cp /path/to/your/master_beast.launch.py launch/
cp /path/to/your/ugv_integrated_driver.py ugv_bringup/
cp /path/to/your/setup.py .
cp /path/to/your/ugv_services_install.sh .
cp /path/to/your/start_ugv.sh .

# Make scripts executable
chmod +x ugv_services_install.sh start_ugv.sh
```

### Step 2: Check Status

```bash
# See what's currently in the layer
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/setup-helper.sh

# Validate all files are present
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/validate.sh
```

### Step 3: Build Image

```bash
# On your build PC (not necessarily the Pi)
cd ~/rpi-image-gen
sudo ./build.sh /home/ubuntu/ws/ugv-rpi-image/config.yaml

# Wait 2-4 hours...
# Output: deploy/ugv-ros2-jazzy-v1.0.0.img.xz
```

### Step 4: Flash and Test

```bash
# Flash to SD card
sudo dd if=deploy/ugv-ros2-jazzy-v1.0.0.img.xz of=/dev/sdX bs=4M status=progress

# Boot the Pi and check files are there
ls -la /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
ls -la /home/ubuntu/ws/ugv_ws/*.sh
```

---

## Adding More Files

### Example: Add a Configuration File

```bash
# 1. Create destination directory in the layer
mkdir -p /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/config

# 2. Copy your config file
cp your_robot_config.yaml \
   /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/config/

# 3. Edit config.yaml to add the mapping
nano /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/config.yaml
```

Add this entry to the `files:` section:

```yaml
files:
  # ... existing files ...
  
  # New config file
  - src: files/config/robot_config.yaml
    dest: /etc/ugv/robot_config.yaml
    mode: "0644"
    owner: root
    group: root
```

### Example: Copy an Entire Directory

If you have many files, copy the whole directory:

```yaml
commands:
  # Copy entire directory with rsync
  - rsync -av files/ugv_beast/launch/ /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
  - chown -R ubuntu:ubuntu /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/
```

---

## File Permissions Guide

### Common Modes

```yaml
mode: "0644"  # Regular files (configs, python files, etc.)
mode: "0755"  # Executable scripts (.sh files, etc.)
mode: "0600"  # Secrets (read/write owner only)
```

### Ownership

```yaml
owner: ubuntu    # Regular user files
group: ubuntu

# OR for system files:
owner: root
group: root
```

---

## Testing Before Building Full Image

**Pro tip:** Test your files locally before building the full image!

```bash
# Copy files manually to your current Pi
cp /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/ugv_beast/launch/master_beast.launch.py \
   /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/

# Test if it works
cd /home/ubuntu/ws/ugv_ws
source /opt/ros/jazzy/setup.bash
source install/setup.bash
export UGV_MODEL=ugv_beast

# Rebuild package
colcon build --packages-select ugv_bringup --symlink-install

# Test launch
ros2 launch ugv_bringup master_beast.launch.py
```

If it works locally, it will work in the image!

---

## Multiple Robot Variants

If you have different configurations for different robot models (e.g., Beast vs Rover):

```
files/
├── ugv_beast/
│   ├── launch/master_beast.launch.py
│   └── config_beast.yaml
├── ugv_rover/
│   ├── launch/master_rover.launch.py
│   └── config_rover.yaml
└── common/
    └── shared_script.sh
```

Then build different images:

```bash
# Option 1: Create separate layers for each variant
# layers/50-custom-beast/
# layers/51-custom-rover/

# Option 2: Use conditional copying in config.yaml
files:
  - src: files/ugv_beast/launch/master_beast.launch.py
    dest: /home/ubuntu/ws/ugv_ws/launch/master.launch.py
    condition: "{{ UGV_MODEL == 'ugv_beast' }}"
```

---

## Common Patterns

### Pattern 1: Overwrite Package Files

Your use case: replace files in an existing ROS package.

```yaml
files:
  # This overwrites the original file
  - src: files/ugv_beast/ugv_bringup/ugv_integrated_driver.py
    dest: /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/ugv_integrated_driver.py
    mode: "0644"

# Then rebuild the package
user_commands:
  - cd /home/ubuntu/ws/ugv_ws
  - source /opt/ros/jazzy/setup.bash
  - colcon build --packages-select ugv_bringup --symlink-install
```

### Pattern 2: Add New Scripts

Add entirely new scripts to the system.

```yaml
files:
  - src: files/scripts/custom_startup.sh
    dest: /home/ubuntu/custom_startup.sh
    mode: "0755"  # Executable!
    owner: ubuntu
    group: ubuntu
```

### Pattern 3: System Configuration

Add system-level configuration files.

```yaml
files:
  # Systemd service
  - src: files/systemd/ugv.service
    dest: /etc/systemd/system/ugv.service
    mode: "0644"
    owner: root
    group: root

commands:
  - systemctl daemon-reload
  - systemctl enable ugv.service
```

### Pattern 4: Templates with Variables

Use variables in your files:

```yaml
files:
  - src: files/config.template.yaml
    dest: /home/ubuntu/config.yaml
    template: true
    variables:
      ROBOT_NAME: "ugv-beast-01"
      ROBOT_IP: "192.168.1.100"
```

In `config.template.yaml`:

```yaml
robot:
  name: {{ ROBOT_NAME }}
  ip: {{ ROBOT_IP }}
```

---

## Troubleshooting

### Files Not Appearing in Image

**Check 1:** Are source files in the right place?

```bash
ls -la /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/files/ugv_beast/
```

**Check 2:** Is layer enabled in main config?

```bash
# Main config.yaml should have:
layers:
  - 50-custom-files
```

**Check 3:** Check build logs for copy errors

```bash
# Look for errors during build
grep -i "custom-files" /path/to/build.log
```

### Permission Denied

Make sure executable files have correct mode:

```yaml
mode: "0755"  # Not 0644!
```

### Files Overwritten After Build

If workspace is rebuilt after copying, files may be overwritten. Solution:

```yaml
# Copy files AFTER building workspace
user_commands:
  # First, build workspace
  - cd /home/ubuntu/ws/ugv_ws && colcon build ...
  
  # Then copy custom files
  - cp files/... /home/ubuntu/ws/ugv_ws/...
```

---

## Quick Reference Commands

```bash
# Check current status
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/setup-helper.sh

# Validate files
bash /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/validate.sh

# View file mappings
cat /home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/config.yaml

# Test locally before building image
cp layers/50-custom-files/files/ugv_beast/your-file.py /target/location/

# Build image
cd ~/rpi-image-gen && sudo ./build.sh /home/ubuntu/ws/ugv-rpi-image/config.yaml
```

---

## More Information

- **Detailed guide:** `/home/ubuntu/ws/ugv-rpi-image/CUSTOM_FILES_GUIDE.md`
- **Layer README:** `/home/ubuntu/ws/ugv-rpi-image/layers/50-custom-files/README.md`
- **Main RPI image guide:** `/home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md`
- **Complete setup summary:** `/home/ubuntu/COMPLETE_SETUP_SUMMARY.md`

---

## Summary

**Your workflow:**

1. Put source files in `layers/50-custom-files/files/ugv_beast/`
2. File mappings already defined in `config.yaml`
3. Build image → files automatically copied to destinations
4. Flash SD card → boot → files are there!

**No need to:**
- Manually copy files on each Pi
- Run setup scripts after flashing
- Remember complex directory structures
- Everything is automated in the image build!

That's it! 🚀
