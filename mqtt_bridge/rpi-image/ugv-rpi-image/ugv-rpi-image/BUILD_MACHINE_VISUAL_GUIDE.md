# Visual Workflow: Build Machine to SD Card

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        YOUR BUILD MACHINE (PC)                          │
└─────────────────────────────────────────────────────────────────────────┘

Step 1: Get ugv-rpi-image configuration from Raspberry Pi
────────────────────────────────────────────────────────

  Raspberry Pi                           Build Machine
  ┌──────────────┐                      ┌──────────────┐
  │              │     scp -r ...       │              │
  │ /home/ubuntu │  ────────────────>   │ ~/ugv-build/ │
  │ /ws/         │                      │              │
  │ ugv-rpi-     │                      │ ugv-rpi-     │
  │ image/       │                      │ image/       │
  └──────────────┘                      └──────────────┘


Step 2: Add your local files (mqtt_bridge)
───────────────────────────────────────────

  Your Local Files                       Image Configuration
  ┌──────────────────┐                  ┌─────────────────────────────┐
  │ ~/projects/      │   cp -r ...      │ ugv-rpi-image/              │
  │ mqtt_bridge/     │  ─────────────>  │ layers/50-custom-files/     │
  │ ├── config/      │                  │ files/                      │
  │ ├── scripts/     │                  │ └── mqtt_bridge/            │
  │ └── systemd/     │                  │     ├── config/             │
  └──────────────────┘                  │     ├── scripts/            │
                                        │     └── systemd/            │
                                        └─────────────────────────────┘


Step 3: Define file mappings in config.yaml
────────────────────────────────────────────

  Edit: layers/50-custom-files/config.yaml

  files:
    - src: files/mqtt_bridge/config/mqtt_config.yaml
      dest: /home/ubuntu/ws/ugv_ws/config/mqtt_config.yaml
    
    - src: files/mqtt_bridge/scripts/mqtt_bridge.py  
      dest: /home/ubuntu/ws/ugv_ws/mqtt_bridge/mqtt_bridge.py


Step 4: Build the image with rpi-image-gen
───────────────────────────────────────────

  ┌──────────────────────────────────────────────────────────────┐
  │  cd ~/rpi-image-gen                                          │
  │  sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml      │
  └──────────────────────────────────────────────────────────────┘
                             │
                             │ [2-4 hours build time]
                             │
                             ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  Output: ~/rpi-image-gen/deploy/                            │
  │          ugv-ros2-jazzy-v1.0.0.img.xz                       │
  └──────────────────────────────────────────────────────────────┘


Step 5: Flash to SD Card
─────────────────────────

  Image File                            SD Card
  ┌──────────────────┐                 ┌────────────┐
  │ ugv-ros2-jazzy-  │    dd or        │            │
  │ v1.0.0.img.xz    │  ─────────────> │  16GB SD   │
  │                  │   RPI Imager    │   Card     │
  │ [16GB image]     │                 │            │
  └──────────────────┘                 └────────────┘


Step 6: Boot Raspberry Pi
──────────────────────────

  ┌─────────────────────────────────────────────────────────────┐
  │                     Raspberry Pi                            │
  │                                                             │
  │  Boots with ALL files already in place:                    │
  │                                                             │
  │  ✅ /home/ubuntu/ws/ugv_ws/                                 │
  │     ├── mqtt_bridge/                                       │
  │     │   ├── mqtt_bridge.py                                 │
  │     │   └── mqtt_test.py                                   │
  │     ├── config/                                            │
  │     │   └── mqtt_config.yaml                               │
  │     ├── src/ugv_main/ugv_bringup/launch/                   │
  │     │   └── master_beast.launch.py                         │
  │     ├── ugv_services_install.sh                            │
  │     └── start_ugv.sh                                       │
  │                                                             │
  │  ✅ /etc/systemd/system/                                    │
  │     └── mqtt-bridge.service                                │
  │                                                             │
  │  ✅ ROS 2 Jazzy installed                                   │
  │  ✅ UGV workspace built                                     │
  │  ✅ All dependencies installed                              │
  │                                                             │
  │  Ready to use immediately! No manual setup needed.         │
  └─────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                        FILE FLOW DIAGRAM
═══════════════════════════════════════════════════════════════════

Build Machine                  rpi-image-gen               Raspberry Pi
                              (Image Build)
┌──────────────┐              ┌──────────┐              ┌──────────────┐
│              │              │          │              │              │
│ ugv-rpi-     │   Build      │  Ubuntu  │   Flash      │  Final       │
│ image/       │   Image      │  24.04   │   to SD      │  System      │
│ ├── layers/  │  ─────────>  │  + ROS2  │  ─────────>  │              │
│ └── 50-      │              │  + Your  │              │ All files    │
│   custom-    │              │  Files   │              │ in place     │
│   files/     │              │          │              │              │
│   └── files/ │              │ [.img]   │              │ Boot & Run   │
│     └── mqtt_│              │          │              │              │
│       bridge/│              │          │              │              │
└──────────────┘              └──────────┘              └──────────────┘
      │                             │                          │
      │ Your source files           │ Baked into image         │ Deployed
      │ (what you have)             │ (automated)              │ (ready!)


═══════════════════════════════════════════════════════════════════
                    QUICK COMMAND REFERENCE
═══════════════════════════════════════════════════════════════════

# On Build Machine:
# ─────────────────

# 1. Copy from Pi
scp -r ubuntu@<PI_IP>:/home/ubuntu/ws/ugv-rpi-image ~/ugv-build/

# 2. Add your files
cp -r ~/projects/mqtt_bridge ~/ugv-build/ugv-rpi-image/layers/50-custom-files/files/

# 3. Edit config (add file mappings)
nano ~/ugv-build/ugv-rpi-image/layers/50-custom-files/config.yaml

# 4. Build image
cd ~/rpi-image-gen
sudo ./build.sh ~/ugv-build/ugv-rpi-image/config.yaml

# 5. Flash to SD card
sudo dd if=deploy/ugv-ros2-jazzy-v1.0.0.img of=/dev/sdX bs=4M status=progress


═══════════════════════════════════════════════════════════════════
                    FOLDER STRUCTURE EXAMPLE
═══════════════════════════════════════════════════════════════════

Build Machine:
~/
├── rpi-image-gen/                    ← Clone from GitHub
│   ├── build.sh                      ← Build script
│   └── deploy/                       ← Output images
│       └── ugv-ros2-jazzy-v1.0.0.img
│
└── ugv-build/
    └── ugv-rpi-image/                ← Copy from Pi
        ├── config.yaml               ← Main configuration
        ├── scripts/
        │   ├── apply-fixes.sh
        │   ├── build-workspace.sh
        │   └── install-python.sh
        └── layers/
            ├── 00-base/
            ├── 10-ros2-jazzy/
            ├── 20-ugv-system/
            ├── 30-ugv-workspace/
            ├── 40-ugv-apps/
            └── 50-custom-files/
                ├── config.yaml       ← File mappings here
                └── files/
                    ├── ugv_beast/    ← UGV Beast files
                    │   ├── launch/
                    │   ├── setup.py
                    │   └── *.sh
                    └── mqtt_bridge/  ← YOUR FILES GO HERE
                        ├── config/
                        ├── scripts/
                        └── systemd/


═══════════════════════════════════════════════════════════════════
                    WHAT GETS COPIED WHERE
═══════════════════════════════════════════════════════════════════

SOURCE (on Build Machine)             DESTINATION (in Final Image)
──────────────────────────            ────────────────────────────

layers/50-custom-files/files/         /home/ubuntu/ws/ugv_ws/
mqtt_bridge/                          mqtt_bridge/
├── config/                           ├── config/
│   └── mqtt_config.yaml    ────────> │   └── mqtt_config.yaml
├── scripts/                          ├── scripts/
│   ├── mqtt_bridge.py      ────────> │   ├── mqtt_bridge.py
│   └── mqtt_test.py        ────────> │   └── mqtt_test.py
└── systemd/                          
    └── mqtt-bridge.service ────────> /etc/systemd/system/
                                      mqtt-bridge.service


═══════════════════════════════════════════════════════════════════
                        KEY CONCEPTS
═══════════════════════════════════════════════════════════════════

1. SOURCE vs DESTINATION
   ─────────────────────
   SOURCE:      Where files are on your Build Machine
   DESTINATION: Where files will be in the final Raspberry Pi image
   
   config.yaml maps: src → dest

2. LAYERS
   ───────
   Layers are processed in order (00, 10, 20, ...)
   Each layer can install packages, copy files, run commands
   
   Your custom files go in: 50-custom-files (executed last)

3. BUILD vs FLASH
   ───────────────
   BUILD:  Creates .img file (on Build Machine, takes hours)
   FLASH:  Writes .img to SD card (takes minutes)
   
   Build once, flash to many SD cards!

4. NO MANUAL SETUP
   ────────────────
   Everything is in the image!
   Boot the Pi → all files are there
   No apt install, no git clone, no setup scripts needed


═══════════════════════════════════════════════════════════════════
                    BENEFITS OF THIS APPROACH
═══════════════════════════════════════════════════════════════════

✅ Reproducible      Same image every time
✅ Fast Deployment   Flash and go, no setup
✅ Version Control   Track changes in Git
✅ Fleet Ready       Flash to 100 Pis, all identical
✅ Offline Deploy    No internet needed on Pi
✅ Tested Config     Test once, deploy many times
✅ Easy Rollback     Keep old .img files for rollback
✅ Disaster Recovery Simple re-flash if Pi corrupted


═══════════════════════════════════════════════════════════════════
                        TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════

Issue: Files not in final image
Solution: Check config.yaml has correct src → dest mappings

Issue: Build fails
Solution: Check Docker is running: docker ps

Issue: Permission denied
Solution: Use sudo: sudo ./build.sh ...

Issue: SD card won't boot
Solution: Re-flash, verify image integrity with sha256sum

Issue: Can't find files on Pi
Solution: Check destination paths in config.yaml
          ssh ubuntu@<PI_IP>
          ls -la /home/ubuntu/ws/ugv_ws/


═══════════════════════════════════════════════════════════════════
                    MORE INFORMATION
═══════════════════════════════════════════════════════════════════

📚 Full Build Machine Guide:
   /home/ubuntu/ws/ugv-rpi-image/BUILD_MACHINE_WORKFLOW.md

📚 Custom Files Quick Start:
   /home/ubuntu/ws/ugv-rpi-image/QUICK_START_CUSTOM_FILES.md

📚 Complete Custom Files Guide:
   /home/ubuntu/ws/ugv-rpi-image/CUSTOM_FILES_GUIDE.md

📚 Main RPI Image Gen Guide:
   /home/ubuntu/ws/RPI_IMAGE_GEN_GUIDE.md
