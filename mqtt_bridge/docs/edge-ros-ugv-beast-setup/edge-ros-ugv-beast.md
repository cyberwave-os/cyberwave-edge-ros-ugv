#UGV Beast ROS 2 Documentation

##📋 Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Hardware Control Logic](#2-hardware-control-logic)
3. [Sensor Fusion with EKF](#3-sensor-fusion-with-ekf)
4. [Topic Map & Interfaces](#4-topic-map--interfaces)
5. [Data Structures & Conventions](#5-data-structures--conventions)
6. [Joint Configuration (URDF)](#6-joint-configuration-urdf)
7. [Minimum Setup Control Guide](#7-minimum-setup-control-guide)
8. [Advanced Control: Joint Trajectories](#8-advanced-control-joint-trajectories)
9. [Technical Best Practices](#9-technical-best-practices)
10. [Automation & Helper Scripts](#10-automation--helper-scripts)

---

##1. System ArchitectureThe UGV Beast utilizes a standard ROS 2 hardware abstraction layer to bridge high-level software with physical actuators.

1. **The Command Layer:** High-level messages are published to topics like `/cmd_vel`.
2. **The Bridge (`ugv_driver`):** This node acts as the primary translator. It subscribes to ROS topics and converts high-level math (e.g., 0.5 \text{ m/s}) into low-level serial bytes.
3. **The Communication Link:** Data is sent via **Serial (TTL/UART)** from the Raspberry Pi to the onboard ESP32.
4. **The Execution Layer (ESP32):** The ESP32 (Slave) calculates PID loops for motor speed and manages GPIO/UART for LEDs and Pan-Tilt servos.

---

##2. Hardware Control Logic
Key launch commands to initialize the hardware:

- **`ros2 run ugv_bringup ugv_driver`**: The most critical command. It opens the serial port (typically `/dev/ttyS0` or USB) and allows the Raspberry Pi to "see" and control the hardware.
- **`ros2 launch ugv_tools teleop_twist_joy.launch.py`**: Launches the Joystick (HID) to `Twist` conversion. Includes a **Deadman's switch** (The 'R' button lock/unlock) for safety.

---

##3. Sensor Fusion with EKF

The UGV Beast now integrates **Extended Kalman Filter (EKF)** sensor fusion for improved localization accuracy.

### Why Sensor Fusion?

Raw wheel encoder odometry (`/odom`) tends to drift over time, especially during:

- Sharp turns or aggressive maneuvers
- Slippery surfaces or wheel slippage
- Long-duration missions

The EKF combines:

- **Wheel Encoders**: Provide good short-term velocity estimates
- **IMU**: Provides stable heading reference (yaw orientation)

**Result:** A more accurate and stable position estimate published to `/odometry/filtered`

### Quick Setup

The EKF is **automatically included** when you use the master launch file:

```bash
ros2 launch master_beast.launch.py robot_id:=robot_ugv_beast_v1
```

### Installation (First Time Only)

If the `robot_localization` package is not installed, run:

```bash
# Automated installation
cd /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast
./install_ekf.sh

# OR manual installation
sudo apt update
sudo apt install ros-${ROS_DISTRO}-robot-localization
```

### Verification

Check that the filtered odometry is being published:

```bash
# List nodes (should include /ekf_filter_node)
ros2 node list

# View filtered odometry
ros2 topic echo /odometry/filtered

# Compare raw vs filtered update rates
ros2 topic hz /odom /odometry/filtered
```

### Configuration

- **Config File:** `/root/ugv_ws/src/mqtt_bridge/config/ekf.yaml`
- **Tuning Parameters:** Adjust process noise covariance for your environment
- **Documentation:** See `/root/ugv_ws/src/mqtt_bridge/docs/EKF_SENSOR_FUSION_SETUP.md` for detailed tuning guide

### Cloud Integration

The filtered odometry is automatically bridged to Cyberwave Cloud:

- **MQTT Topic:** `cyberwave/pose/{twin_uuid}/filtered`
- **Update Rate:** ~30 Hz
- **Purpose:** Provides stable position data for digital twin visualization

---

##4. Topic Map & Interfaces
Below are the topics exposed by the `ugv_driver`.

### Terminology

- **Downstream**: Commands from Cyberwave/Frontend to the Robot (MQTT → ROS).
- **Upstream**: Telemetry/Feedback from the Robot to Cyberwave (ROS → MQTT).

| Topic Name            | Stream         | Message Type                 | Description               | Units                               |
| :-------------------- | :------------- | :--------------------------- | :------------------------ | :---------------------------------- |
| `/cmd_vel`            | **Downstream** | `geometry_msgs/Twist`        | Main movement control.    | Linear: **m/s**, Angular: **rad/s** |
| `/ugv/led_ctrl`       | **Downstream** | `std_msgs/Float32MultiArray` | Chassis and Camera LEDs.  | **0–255** brightness                |
| `/ugv/pt_ctrl`        | **Downstream** | `std_msgs/Float32MultiArray` | Pan-Tilt servo control.   | **Degrees**                         |
| `/ugv/oled_ctrl`      | **Downstream** | `std_msgs/String`            | Text for onboard OLED.    | N/A                                 |
| `/ugv/joint_states`   | **Upstream**   | `sensor_msgs/JointState`     | Wheel and Servo feedback. | Pos: **rad**, Vel: **rad/s**        |
| `/ugv/imu`            | **Upstream**   | `sensor_msgs/Imu`            | 9-axis IMU data.          | m/s², rad/s                         |
| `/ugv/battery_status` | **Upstream**   | `sensor_msgs/BatteryState`   | Voltage and power levels. | **Volts**                           |
| `/odom`               | **Upstream**   | `nav_msgs/Odometry`          | Raw encoder odometry.     | m, rad                              |
| `/odometry/filtered`  | **Upstream**   | `nav_msgs/Odometry`          | EKF-filtered odometry.    | m, rad                              |

---

##4. Data Structures & Conventions

To ensure compatibility between the frontend and the bridge, please note the following data structures:

### Velocity (`cmd_vel`)

- **Downstream (MQTT → ROS)**: The bridge expects a **dictionary** for `linear` and `angular` components to match the `geometry_msgs/Twist` structure.
  - _Example_: `{"linear": {"x": 0.5, "y": 0, "z": 0}, "angular": {"x": 0, "y": 0, "z": 0.5}}`
- **Keyboard Bindings**: In the frontend policy configuration, individual keys may use **scalars** (e.g., `linear: 1.0`). These are internal mapping values that the controller uses to calculate the final velocity before publishing the dictionary format above.

### Units Reference

- **Linear Velocity**: Meters per second (**m/s**).
- **Angular Velocity**: Radians per second (**rad/s**).
- **Joint Positions**: Radians (**rad**).
- **LED Brightness**: **0** (OFF) to **255** (MAX).

---

##5. Joint Configuration (URDF)
The `ugv_description` defines specific joints for 3D spatial awareness in RViz.

###Chassis Joints (Actuated via Encoders)Simulated as four wheels to calculate odometry for the tracked system:

- `left_up_wheel_link_joint` / `left_down_wheel_link_joint`
- `right_up_wheel_link_joint` / `right_down_wheel_link_joint`

###Pan-Tilt Joints (Actuated via Servos)\* **`pt_base_link_to_pt_link1` (Pan/Yaw):** Horizontal camera rotation.

- **`pt_link1_to_pt_link2` (Tilt/Pitch):** Vertical camera rotation.

###Fixed Joints (Structural)Required for the Transform Tree (TF):

- `base_footprint_joint`: Chassis to floor connection.
- `lidar_joint` / `camera_joint`: Sensor-to-body alignment.

---

##6. Minimum Setup Control Guide
Use these terminal commands for manual control without external hardware.

###Step A: Preparation (Run Once per Session)```bash
export UGV_MODEL=ugv_beast
source /root/ugv_ws/install/setup.bash
ros2 run ugv_bringup ugv_driver

````

###Step B: Command Palette (New Terminal)* **Move Forward:**
`ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"`
* **Stop:**
`ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"`
* **Pivot Right:**
`ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: -0.5, y: 0.0, z: 0.0}}"`
* **Lights ON (Full):**
`ros2 topic pub --once /ugv/led_ctrl std_msgs/msg/Float32MultiArray "{data: [255.0, 255.0]}"`
* **Center Pan-Tilt:**
`ros2 topic pub --once /ugv/pt_ctrl std_msgs/msg/Float32MultiArray "{data: [0.0, 0.0]}"`

---

##7. Advanced Control: Joint Trajectories
For high-precision mapping or simulation, you can target joints directly using the `scaled_joint_trajectory_controller`.

###Command all wheels forward:```bash
ros2 topic pub --once /scaled_joint_trajectory_controller/joint_trajectory trajectory_msgs/msg/JointTrajectory "{
  joint_names: ['left_up_wheel_link_joint', 'left_down_wheel_link_joint', 'right_up_wheel_link_joint', 'right_down_wheel_link_joint'],
  points: [{
    positions: [0.0, 0.0, 0.0, 0.0],
    velocities: [1.0, 1.0, 1.0, 1.0],
    time_from_start: {sec: 1, nanosec: 0}
  }]
}"

````

| ###Parameter Breakdown | Parameter                                                                              | Meaning |
| ---------------------- | -------------------------------------------------------------------------------------- | ------- |
| `joint_names`          | Specific motors to engage (use all 4 for balanced tracks).                             |
| `positions`            | Target rotation angle in **Radians**.                                                  |
| `velocities`           | Rotation speed in **Radians/sec** (determines throttle).                               |
| `time_from_start`      | **Critical:** Duration to reach goal. Setting to `0` may cause commands to be ignored. |

---

##7. Technical Best Practices###The Safety "Heartbeat"The `ugv_driver` has a safety timeout.

- **`--once`**: Useful for testing; the robot may move briefly and stop.
- **`-r 10`**: Recommended for smooth motion. Publishes at 10\text{ Hz}.
  `ros2 topic pub -r 10 /cmd_vel ...`

###Track SynchronizationThe UGV Beast is a tracked vehicle. While software controls 4 joints, the `left_up/down` and `right_up/down` pairs are physically linked. Always command identical values to linked pairs to avoid track tension or slippage.

###Live MonitoringTo monitor real-time track and servo feedback:

```bash
ros2 topic echo /ugv/joint_states
```

### Running the Edge for Joint States

To be able to read the `/ugv/joint_states` topic, the UGV Beast edge must run this:

```bash
ros2 launch ugv_bringup bringup_lidar.launch.py
```

### Important: Resource Contention Warning

If you experience issues communicating with the robot hardware, check for **Resource Contention** on the serial port `/dev/ttyAMA0`.

This problem occurs when two separate processes attempt to communicate with the robot hardware simultaneously:

1. `ros2 run ugv_bringup ugv_driver` (Manual Node)
2. `ros2 launch ugv_bringup bringup_lidar.launch.py` (Launch File)

Ensure that only one of these is running at a time.

## EDGE Configuration

### SSH connection

accordingly to this [UGV Beast PI ROS2](https://www.waveshare.com/wiki/UGV_Beast_PI_ROS2)

enter ninto the raspberry to set up the wifi and ssh connection. follow the previous link for a better explaination

```bash
cd ~/ugv_rpi
cd AccessPopup/
sudo chmod +x installconfig.sh
```

2.  ssh

```bash
sudo systemctl start ssh

sudo systemctl enable ssh

sudo systemctl enable ssh

sudo systemctl status ssh
```

after that there is a raspberry that expose an ssh servie.
we can call thi endpoint in that way

- EdgeUGV, port: 22 ( usr: ws, psw: ws)

Establish a connection to:

```bash
ssh root@<IP_address> -p 22
```

## first startup

when you have established the connection with `edgeUGV` endpoint
you need to follow this steps
[UGV Beast PI ROS2 1. Preparation](https://www.waveshare.com/wiki/UGV_Beast_PI_ROS2_1._Preparation)
[ugv_ws](https://github.com/waveshareteam/ugv_ws)
Real time display of tasks and process information currently running in the system on the terminal:
Wait a few seconds, and you will see the PID with COMMAND as python.

```bash
top
```

```bash
Kill -9 Python process PID
```

```bash
crontab -e
```

open crontab's configuration file, you can see the following two lines:

```bash
@reboot ~/ugv_pt_rpi/ugv-env/bin/python ~/ugv_pt_rpi/app.py >> ~/ugv.log 2>&1
@reboot /bin/bash ~/ugv_pt_rpi/start_jupyter.sh >> ~/jupyter_log.log 2>&1
```

Add a "#" sign at the beginning of the line "...app.py >> ...." to comment out this line, as follows:

```bash
#@reboot ~/ugv_pt_rpi/ugv-env/bin/python ~/ugv_pt_rpi/app.py >> ~/ugv.log 2>&1
@reboot /bin/bash ~/ugv_pt_rpi/start_jupyter.sh >> ~/jupyter_log.log 2>&1
```

Start Docker remote service

```bash
cd /home/ws/ugv_ws
sudo chmod +x ros2_humble.sh remotessh.sh
```

Execute the script file ros2_humble.sh to start the Docker remote service:

```bash
./ros2_humble.sh
```

## Automation (The "Boot to ROS" Setup)

This is the most important part: making the robot accessible via SSH on Port 23 automatically.

1. Enable Docker Autostart

```bash
docker update --restart unless-stopped ugv_rpi_ros_humble
```

2. Create the SSH Auto-Trigger Service
   Create a system service to start the SSH server inside the container at boot.

```bash

sudo nano /etc/systemd/system/ugv_ssh_start.service
Paste this content:

Ini, TOML

[Unit]
Description=Start SSH inside UGV Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/docker exec ugv_rpi_ros_humble service ssh start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

3. Activate the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable ugv_ssh_start.service
sudo systemctl start ugv_ssh_start.service
```

---

## 9. Automation & Helper Scripts

Pre-configured scripts are available in `scripts/ugv_beast/` to simplify environment setup and development:

### 1. Master Launch File (Recommended)

The **Master Launch File** combines all essential nodes into a single launch command. This is the simplest and most reliable way to start the entire UGV Beast system.

**Location:** `/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py`

**What it launches:**

- `ugv_driver` - Serial bridge between Raspberry Pi and ESP32
- `base_node` - Digital Twin position updates and odometry publishing
- `mqtt_bridge_node` - Cloud connectivity via MQTT
- `camera.launch.py` - Video streaming pipeline

**Usage:**

```bash
# Start the complete UGV Beast stack with one command
ros2 launch /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py robot_id:=robot_ugv_beast_v1

# Or with custom robot ID
ros2 launch /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py robot_id:=your_robot_id_here
```

**Advantages:**

- Single command startup - no need to manage multiple terminals
- Prevents serial port contention issues
- Consistent configuration across launches
- All nodes start together with proper dependencies

**Note:** This launch file is designed to prevent the common "Resource Contention" error by ensuring only one `ugv_driver` instance is running.

#### Technical Details: Master Launch File Structure

The `master_beast.launch.py` file uses ROS 2's Python launch API to orchestrate multiple nodes:

**Key Components:**

1. **Launch Arguments:**

   - `robot_id`: Configurable robot identifier for Cyberwave cloud integration (default: `robot_ugv_beast_v1`)

2. **Direct Node Launches:**

   - `ugv_driver`: Hardware control node (serial bridge)
   - `base_node`: Odometry and digital twin synchronization
   - `mqtt_bridge_node`: MQTT connectivity with parameters from `config/params.yaml`

3. **Included Launch Files:**
   - `camera.launch.py`: Video streaming system (CSI/USB camera support)

**Configuration Paths:**

- MQTT config: `mqtt_bridge/config/params.yaml`
- Camera launch: `ugv_vision/launch/camera.launch.py`

**Customization:**
To modify the launch file for your needs, edit:

```bash
nano /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py
```

Common modifications:

- Change default `robot_id`
- Add additional nodes (e.g., LiDAR, navigation)
- Modify output modes (`screen` vs `log`)
- Add remappings or parameter overrides

#### Comparison: Launch Methods

| Method                           | Use Case                          | Advantages                                                                 | Disadvantages                                                    |
| -------------------------------- | --------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **Master Launch File**           | Production, Cyberwave integration | ✅ Single command<br>✅ Prevents contention<br>✅ Consistent config        | ⚠️ Less flexibility for debugging                                |
| **tmux Script (`start_ugv.sh`)** | Development, monitoring           | ✅ Separate windows<br>✅ Individual log access<br>✅ Easy troubleshooting | ⚠️ More complex setup<br>⚠️ Manual terminal management           |
| **Manual Launch**                | Testing, debugging                | ✅ Maximum control<br>✅ Component isolation                               | ⚠️ Serial port contention risk<br>⚠️ Multiple terminals required |

### 2. Full Environment Startup (Alternative with tmux)

Automatically cleans up existing processes and starts the entire UGV stack (Bringup, Driver, Vision, BaseNode, and MQTT Bridge) in a managed `tmux` session with separate windows for each component.

```bash
# Start everything
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/start_ugv.sh

# Start everything and automatically attach to logs
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/start_ugv.sh --logs

# Start hardware only (skip MQTT bridge for manual execution)
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/start_ugv.sh --no-bridge
```

- **View processes**: `tmux attach -t ugv_env`
- **Navigation**: Use `Ctrl+B` then `n`/`p` to switch between windows.

### 3. MQTT Bridge Clean Build & Run

Removes existing build/install artifacts for the bridge, performs a fresh `colcon build`, and runs the node with the default UGV parameters.

```bash
# Rebuild and run (logs shown by default)
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh

# Rebuild and run with explicit logs flag
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh --logs

# Rebuild ONLY (do not run)
/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/clean_build_mqtt.sh --no-run
```

---

### ROS2 Hubble Docker container connection

Now our edge have two ssh connection.  
The workstation:

- EdgeUGV, port: 22 ( usr: ws, psw: ws)
- and the EdgeUGV-ros2-docker, port 23 ( usr: root, psw: ws )

```bash
ssh root@<IP_address> -p 22
ssh root@<IP_address> -p 23
```

using

```bash
ssh root@<IP_address> -p 23
```

## first setup

```bash
cd ~/ugv_ws
rm -rf build install log

chmod +x build_first.sh
./build_first.sh

# Now rebuild from scratch
colcon build --symlink-install
```

```bash
cd ugv_ws
file /root/ugv_ws/ugv_description.zip
source /root/ugv_ws/install/setup.bash
echo "source /root/ugv_ws/install/setup.bash" >> ~/.bashrc
```

## UGV Beast ROS2 drivers theory

When working with the UGV Beast, understanding the difference between a **Node** (`ros2 run`) and a **Launch File** (`ros2 launch`) is critical to avoiding hardware conflicts.

If you activate these commands incorrectly, you will encounter the **Serial Port Contention** issue described below.

---

###1. Breakdown of Activation Methods####**Method A: `ros2 run ugv_bringup ugv_driver**`\* **What it is:** A manual execution of a single ROS 2 node.

- **Purpose:** It starts the serial bridge between the Raspberry Pi and the ESP32.
- **Usage:** Best used only for isolated testing of motor commands or LED controls when no other systems (like LiDAR or Navigation) are needed.

####**Method B: `ros2 launch ugv_bringup bringup_lidar.launch.py**`\* **What it is:** A high-level script that starts **multiple** nodes simultaneously.

- **Purpose:** It typically launches:

1. The `ugv_driver` (Serial bridge).
2. The `lidar_node` (Laser scanner driver).
3. The `robot_state_publisher` (Calculates 3D transforms/TFs).

- **Importance:** This is necessary for SLAM, Navigation, and monitoring battery/joint positions.

####**Method C: `ros2 launch ugv_vision camera.launch.py**`\* **What it is:** A dedicated launch file for the vision system.

- **Purpose:** Activates the CSI or USB camera driver and the image processing pipeline.
- **Concurrency Note:** This usually runs on a separate interface (USB or MIPI CSI) and rarely conflicts with the serial port, so it is safe to run alongside Method B.

---

###2. Potential Concurrent Issues: Serial Port ContentionThe most common "trap" for new users is running **Method A and Method B at the same time.**

**The Conflict:** The physical serial port on the Raspberry Pi (`/dev/ttyAMA0` or `/dev/ttyS0`) is a single-lane highway. Only one process can "own" it at a time. Because the `bringup_lidar.launch.py` script **already contains** the `ugv_driver` node within its instructions, running the manual `ros2 run` command creates a second "driver" trying to talk to the same hardware.

####**The Consequences of Contention:\*** **Packet Collision:** Two processes send commands at the same time, resulting in electrical noise or garbage data at the ESP32.

- **Buffer Depletion:** Process 1 reads half of a JSON sensor string, and Process 2 reads the other half. Neither process receives a valid message.
- **The "KeyError" Crash:** Because Process 1 only got a partial string (e.g., `{"temp": 25, "v"`), the code fails when it tries to look for the missing keys like `"gx"` or `"voltage"`.
- **Ghost Movements:** The robot may stutter or ignore commands because the serial buffer is constantly being cleared by the "competing" node.

---

###3. Best Practice WorkflowTo avoid these issues, follow this strict "one-driver" rule:

| Goal                       | Command to Use                                    | Warning                                     |
| -------------------------- | ------------------------------------------------- | ------------------------------------------- |
| **Full Navigation / SLAM** | `ros2 launch ugv_bringup bringup_lidar.launch.py` | **Do not** run `ugv_driver` manually.       |
| **Visual Mapping**         | `ros2 launch ugv_vision camera.launch.py`         | Safe to run with the LiDAR launch.          |
| **Simple Hardware Test**   | `ros2 run ugv_bringup ugv_driver`                 | Use **only** if no launch files are active. |

**Pro Tip:** If you encounter a `KeyError` or a "Device Busy" error, run `ps aux | grep ugv` in your terminal to find and `kill` any zombie driver processes that might still be holding the serial port open in the background.

In ROS 2, launch files are the "orchestrators." While `ros2 run` starts a single node, `ros2 launch` starts an entire system of nodes, parameters, and configurations.

On the **UGV Beast**, Waveshare has organized these into specific scopes. Using the wrong one usually results in the **Serial Port Contention** you described. Here is the breakdown of the existing and useful launch alternatives.

---

###1. The "Base" Scopes (Hardware Initialization)These launch files are found in `ugv_bringup`. They are designed to "bring the robot to life."

| Launch Command                                     | Scope                                                   | Included Nodes                                       |
| -------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------- |
| `ros2 launch ugv_bringup ugv_driver.launch.py`     | **Minimal Hardware:** Only serial communication.        | `ugv_driver`                                         |
| `ros2 launch ugv_bringup bringup_lidar.launch.py`  | **Navigation Ready:** Full physical state + Lidar scan. | `ugv_driver`, `lidar_node`, `robot_state_publisher`  |
| `ros2 launch ugv_bringup bringup_camera.launch.py` | **Vision Ready:** Full physical state + Camera stream.  | `ugv_driver`, `camera_node`, `robot_state_publisher` |

> **⚠️ Contention Risk:** You should **never** run more than one of these at a time. Both `bringup_lidar` and `bringup_camera` call the `ugv_driver` internally. If you run both, they will fight for `/dev/ttyAMA0`.

---

###2. The "Perception" Scopes (Vision & Sensors)These focus on processing raw data into useful information.

| Launch Command                                 | Scope                                        | Use Case                                |
| ---------------------------------------------- | -------------------------------------------- | --------------------------------------- |
| `ros2 launch ugv_vision camera.launch.py`      | Starts the CSI/USB camera stream.            | Remote monitoring or AI line following. |
| `ros2 launch ugv_vision rtabmap.launch.py`     | Visual SLAM using the depth camera.          | 3D Mapping and obstacle avoidance.      |
| `ros2 launch ugv_bringup imu_filter.launch.py` | Processes raw IMU into a stable orientation. | Improving odometry precision on slopes. |

---

###3. The "Navigation & Mapping" ScopesThese are high-level behaviors that require a "Base Scope" to be running first.

| Launch Command                                | Scope                                         | Use Case                                    |
| --------------------------------------------- | --------------------------------------------- | ------------------------------------------- |
| `ros2 launch ugv_nav2 navigation2.launch.py`  | Starts the Nav2 stack (planners/controllers). | Autonomous waypoint navigation.             |
| `ros2 launch ugv_slam cartographer.launch.py` | Starts 2D Lidar-based mapping.                | Creating a floor plan of a room.            |
| `ros2 launch ugv_slam slam_toolbox.launch.py` | Alternative to Cartographer.                  | Higher performance mapping for large areas. |

---

###4. The "Interface" ScopesThese handle how you interact with the robot.

| Launch Command                                     | Scope                                             | Use Case                                       |
| -------------------------------------------------- | ------------------------------------------------- | ---------------------------------------------- |
| `ros2 launch ugv_tools teleop_twist_joy.launch.py` | Maps a Bluetooth/USB joystick to movement.        | Manual driving with a controller.              |
| `ros2 launch mqtt_bridge mqtt_bridge.launch.py`    | Connects ROS 2 topics to an external MQTT broker. | Remote control via Digital Twin/Web Dashboard. |
| `ros2 launch ugv_description display.launch.py`    | Loads the URDF and starts a joint state GUI.      | Debugging the 3D model in RViz.                |

---

###🛡️ How to Avoid Concurrency IssuesTo prevent **Serial Port Contention**, follow this "Golden Rule" of hierarchy:

1. **Pick ONE "Bringup" file:** Usually `bringup_lidar.launch.py`. This "owns" the serial port.
2. **Add "Perception" as needed:** Run `camera.launch.py` in a second terminal. This uses a different hardware bus (USB/CSI), so there is no conflict.
3. **Run "Behavior" on top:** Run `navigation2.launch.py` in a third terminal. It listens to the topics created by the first two.

**If you try to run `ugv_driver.launch.py` AND `navigation2.launch.py` (which might try to call its own driver), you will see the mangled JSON and `KeyError` crashes.**

### Build MQTT_bridge

```bash
cd /root/ugv_ws/src/
git clone <mqtt_bridge>
```

```bash
# Navigate to workspace root
cd /root/ugv_ws

# Source the ROS 2 installation (IMPORTANT!)
source /opt/ros/humble/setup.bash
source install/setup.bash
#Clean the package:
rm -rf install/mqtt_bridge build/mqtt_bridge

#if necesesary
 export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

# Build the package
colcon build --packages-select mqtt_bridge --cmake-args -DBUILD_TESTING=OFF
#or
colcon build --packages-select mqtt_bridge

# Source the workspace overlay
source /root/ugv_ws/install/setup.bash
source install/setup.bash
```

Here are the proper commands to build the MQTT bridge:

the first time you need to install cyberwave-python sdk

```bash
pip install cyberwave
```

### Launch MQTT Bridge

```bash
# Launch with robot configuration
ros2 launch mqtt_bridge mqtt_bridge.launch.py robot_id:=robot_ugv_beast_v1
```

## Re-Build the packege after some change

```bash
# 1. Rebuild with the fix
cd /root/ugv_ws
source /opt/ros/humble/setup.bash
rm -rf build/ install/ log/
colcon build --packages-select mqtt_bridge --cmake-args -DBUILD_TESTING=OFF
source install/setup.bash

# 2. Launch the bridge
ros2 launch mqtt_bridge mqtt_bridge.launch.py robot_id:=robot_ugv_beast_v1
```

---

## Start the rover control

Setting Up the Container (Next Time)

When you enter the `ros2_humble` container in the future, follow these steps to ensure everything is configured correctly from the start.

Automated Configuration (Do once)
Since you already ran the `echo` commands into `~/.bashrc`, these variables will now load automatically. To verify they are there:

```bash
cat ~/.bashrc | grep -E "UGV_MODEL|LDLIDAR_MODEL"
```

Workspace Initialization
Every time you open a **new terminal** inside the container, you **must** source the ROS 2 workspace:

```bash
source /root/ugv_ws/install/setup.bash
```

## Launch the Core System

### 🚀 Recommended: Using the Master Launch File

The simplest and most reliable way to start the complete UGV Beast system:

```bash
# Ensure models are set (if not in .bashrc)
export UGV_MODEL=ugv_beast
export LDLIDAR_MODEL=ld19

# Source the workspace
cd /root/ugv_ws
source /root/ugv_ws/install/setup.bash

# Launch everything with one command
ros2 launch /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py robot_id:=robot_ugv_beast_v1
```

This single command starts:

- ✅ Hardware driver (`ugv_driver`)
- ✅ Digital twin synchronization (`base_node`)
- ✅ Cloud connectivity (`mqtt_bridge_node`)
- ✅ Camera streaming (`camera.launch.py`)

### Alternative: Manual Launch (Advanced Users)

For debugging or testing individual components, you can launch nodes separately. **⚠️ Warning:** This approach requires careful management to avoid serial port contention.

```bash
# Option 1: Minimal hardware only (for testing)
# starts the serial bridge between the Raspberry Pi and the ESP32
ros2 run ugv_bringup ugv_driver

# Option 2: Full hardware with LiDAR (SLAM/Navigation ready)
# This already includes ugv_driver internally - DO NOT run both!
ros2 launch ugv_bringup bringup_lidar.launch.py

# Option 3: Camera system (safe to run with Option 2)
# Runs on separate interface (USB or MIPI CSI)
ros2 launch ugv_vision camera.launch.py
```

**Launch the MQTT Bridge Separately (if not using Master Launch File):**

```bash
# Terminal 2 - Launch bridge
cd /root/ugv_ws
source /root/ugv_ws/install/setup.bash
ros2 launch mqtt_bridge mqtt_bridge.launch.py robot_id:=robot_ugv_beast_v1
```

**⚠️ Important:** When using manual launch, remember:

- Only run **ONE** bringup command at a time
- `bringup_lidar.launch.py` already includes `ugv_driver`
- Running multiple driver instances causes serial port contention

---

## TEST

run this to check that all the library used are ok

```bash
ç
source install/setup.bash
ros2 launch ugv_description display.launch.py use_rviz:=true
```

then ctrl + c and run

```bash
ros2 run ugv_bringup ugv_driver
```

now we can control the rover publishing on ros2 topics

i.e. torn on the light

According to the default assembly method, IO4 controls the chassis headlight (the light next to the OKA camera), and IO5 controls the headlight (the light on the USB camera pan-tilt). You can control the switching of these two switches and adjust the voltage level by sending the corresponding commands to the sub-controller.

```bash
cd /ugv_ws
ros2 topic pub /ugv/led_ctrl std_msgs/msg/Float32MultiArray "{data: [255, 255]}" -1
```

data: [0, 0]——The first 0 is the switch that controls the IO4 interface (chassis headlight); the second 0 is the switch that controls the IO5 interface (headlight).

```bash
ros2 topic pub /ugv/led_ctrl std_msgs/msg/Float32MultiArray "{data: [0, 0]}" -1
```

### 3. Essential Monitoring Commands

If you need to verify the system is "alive," use these commands in a separate terminal:

- **Check Battery/Voltage:**
  ```bash
  ros2 topic echo /voltage
  ```
- **Check if Lidar is spinning (Frequency):**
  ```bash
  ros2 topic hz /scan
  ```
- **Verify all Hardware Nodes are running:**
  ```bash
  ros2 node list
  # Should see: /ugv_driver, /mqtt_bridge_node, /robot_state_publisher, etc.
  ```
- **Test the Camera Pan-Tilt (Manual Command):**
  ```bash
  ros2 topic pub --once /ugv/joint_states sensor_msgs/msg/JointState "{name: ['pt_base_link_to_pt_link1', 'pt_link1_to_pt_link2'], position: [0.5, -0.2]}"
  ```

## ROS command-line tools instead\*\*

Since you're working with robotics on a headless Raspberry Pi, you can use command-line tools to monitor your system:

to get most of this ros2 information you should run

```bash
ros2 launch ugv_bringup bringup_lidar.launch.py
```

```bash
# Monitor topics
ros2 topic list
ros2 topic echo /cmd_vel

# Monitor nodes
ros2 node list
ros2 node info /joy_ctrl

# Use rqt without GUI
ros2 run rqt_graph rqt_graph  # (still needs display)
```

```bash
source ~/ugv_ws/install/setup.bash && ros2 node info /ugv_bringup
```

## Show joints state

```bash
ros2 topic echo /ugv/joint_states --once

ros2 interface show sensor_msgs/msg/JointState

ros2 node info /ugv_driver
```

# View camera information

```bash
sudo apt-get install -y v4l-utils
```

## Check Camera Info (Command Line)

```bash
v4l2-ctl --device=/dev/video0 --list-formats-ext

source ~/ugv_ws/install/setup.bash && ros2 launch ugv_vision camera.launch.py &
```

```bash
ros2 topic info /image_raw
```

```bash
ros2 topic echo /camera_info --once

# Check image publish rate
ros2 topic hz /image_raw

# Check topic info
ros2 topic info /image_raw
```

Option 4: Save Images to File

```bash
ros2 run image_view image_saver --ros-args -r image:=/image_raw
# Save a single image
ros2 run image_view image_saver --ros-args -r image:=/image_raw
```

```bash
source /root/ugv_ws/install/setup.bash
ros2 launch mqtt_bridge mqtt_bridge.launch.py robot_id:=robot_ugv_beast_v1
ros2 node info /ugv_driver

ros2 topic list && ros2 node list

ros2 topic hz /ugv/led_ctrl & ros2 topic hz /cmd_vel & ros2 topic hz /ugv/joint_states

ros2 topic info /ugv/joint_states --verbose

ros2 topic echo /voltage
```

## **3. Test Headlights (LED Control)**

```bash
# Set your UUID first
export TWIN_UUID="00000000-0000-0000-0000-000000000000"  # Replace with yours

# Monitor LED topic (Terminal 3)
ros2 topic echo /ugv/led_ctrl

sudo apt update
sudo apt install -y mosquitto-clients

# Turn all lights ON (Terminal 2)
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"led_ctrl","data":{"all":255}}'

# Wait 3 seconds, then turn OFF
sleep 3
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"led_ctrl","data":{"all":0}}'

# Test chassis light only
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"led_ctrl","data":{"chassis_light":255,"camera_light":0}}'
```

## **4. Test Velocity Control**

```bash
# Monitor velocity commands (Terminal 3)
ros2 topic echo /cmd_vel

# Send forward motion (Terminal 2)
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"cmd_vel","data":{"linear":{"x":0.3,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0}}}'

# Stop
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"cmd_vel","data":{"linear":{"x":0,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0}}}'

# Turn in place
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"cmd_vel","data":{"linear":{"x":0,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0.5}}}'
```

## **5. Test Pan-Tilt Camera**

```bash
# Monitor joint states (Terminal 3)
ros2 topic echo /ugv/joint_states

# Move camera (Terminal 2)
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"pan_tilt","data":{"pan":0.5,"tilt":0.3}}'

# Center camera
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"pan_tilt","data":{"pan":0,"tilt":0}}'
```

## **6. Test Emergency Stop**

```bash
# Monitor emergency stop (Terminal 3)
ros2 topic echo /emergency_stop

# Activate E-stop (Terminal 2)
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"estop","data":{"activate":true}}'

# Deactivate E-stop
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 \
  -t "cyberwave/twin/$TWIN_UUID/command" \
  -m '{"command":"estop","data":{"activate":false}}'
```

## **9. Direct ROS Test (No MQTT)**

```bash
# Test without MQTT - publish directly to ROS topics

# Test headlights
ros2 topic pub /ugv/led_ctrl std_msgs/msg/Float32MultiArray "{data: [255, 255]}" -1

# Test velocity
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.3, y: 0, z: 0}, angular: {x: 0, y: 0, z: 0}}" -1

# Stop
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0, y: 0, z: 0}, angular: {x: 0, y: 0, z: 0}}" -1
```

## **Quick Test Sequence (Copy-Paste)**

```bash
# Replace with your actual UUID!
export TWIN_UUID="00000000-0000-0000-0000-000000000000"

# Test 1: Lights ON
echo "Testing: Lights ON"
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "cyberwave/twin/$TWIN_UUID/command" -m '{"command":"led_ctrl","data":{"all":255}}'
sleep 2

# Test 2: Lights OFF
echo "Testing: Lights OFF"
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "cyberwave/twin/$TWIN_UUID/command" -m '{"command":"led_ctrl","data":{"all":0}}'
sleep 2

# Test 3: Move forward slowly
echo "Testing: Move forward"
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "cyberwave/twin/$TWIN_UUID/command" -m '{"command":"cmd_vel","data":{"linear":{"x":0.2,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0}}}'
sleep 2

# Test 4: Stop
echo "Testing: Stop"
mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "cyberwave/twin/$TWIN_UUID/command" -m '{"command":"cmd_vel","data":{"linear":{"x":0,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0}}}'

echo "Tests complete!"
```

**Monitor all UGV topics at once:**

```bash
ros2 topic echo /ugv/led_ctrl & \
ros2 topic echo /cmd_vel & \
ros2 topic echo /ugv/joint_states
```

```bash

```

## Control from MQTT

```bash
 mosquitto_pub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "localcyberwave/joint/60d542ec-7d65-48b7-83dc-ecd89adbacec/update" -m '{
  "source_type": "tele",
  "joint_names": ["left_up_wheel_link_joint"],
  "points": [
    {
      "positions": [0.5],
      "velocities": [0.0],
      "time_from_start": {
        "sec": 0,
        "nanosec": 100000000
      }
    }
  ]
}'
```

```bash
 mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -mqttcyb231 -t "localcyberwave/joint/60d542ec-7d65-48b7-83dc-ecd89adbacec/update" -v
```

## chech the messages

To retrieve the **Commands** (Downstream) and the **Upstream Traffic** (Odometry and Joint States) for your specific twin, use the following `mosquitto_sub` commands.

These commands assume your environment prefix is `local` (as seen in your logs).

### 1. Retrieve Downstream Commands (What the frontend sends)

This will show the `cmd_vel` and `led_ctrl` messages sent from your keyboard:

```bash
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "localcyberwave/twin/ace84397-be7d-4f4d-9f66-74217b2f3509/command" -v
```

### 2. Retrieve Upstream Odometry (The physical robot's position)

This will show the `position` and `rotation` updates sent from the physical robot to update the digital twin:

```bash
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "localcyberwave/twin/ace84397-be7d-4f4d-9f66-74217b2f3509/status/odom" -v
```

### 3. Retrieve Upstream Joint States (Wheel and Pan-Tilt rotation)

This shows the status of individual joints (e.g., wheel rotation):

```bash
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "localcyberwave/joint/ace84397-be7d-4f4d-9f66-74217b2f3509/update" -v
```

### 4. Spy on ALL traffic for this Twin (Recommended)

This wildcard command will catch **every** message associated with this twin across both `twin` and `joint` scopes:

```bash
mosquitto_sub -h mqtt.cyberwave.com -p 1883 -u mqttcyb -P mqttcyb231 -t "localcyberwave/+/ace84397-be7d-4f4d-9f66-74217b2f3509/#" -v
```

### Summary Table for UUID `ace84...509`:

| Scope        | Direction  | MQTT Topic                                                             |
| :----------- | :--------- | :--------------------------------------------------------------------- |
| **Command**  | Downstream | `localcyberwave/twin/ace84397-be7d-4f4d-9f66-74217b2f3509/command`     |
| **Odometry** | Upstream   | `localcyberwave/twin/ace84397-be7d-4f4d-9f66-74217b2f3509/status/odom` |
| **Joints**   | Upstream   | `localcyberwave/joint/ace84397-be7d-4f4d-9f66-74217b2f3509/update`     |

### 📝 Troubleshooting Documentation: Serial Port Resource Conflict

---

#### 🚩 Symptoms

The following errors were observed in the terminal logs:

1.  **JSON Decode Errors:** `JSON decode error: Expecting property name enclosed in double quotes` or `Extra data`.
2.  **Hardware Failures:** `[base_ctrl.feedback_data] unexpected error: device reports readiness to read but returned no data`.
3.  **Python Crashes:**
    ```python
    File "/root/ugv_ws/build/ugv_bringup/ugv_bringup/ugv_bringup.py", line 125, in publish_imu_data_raw
    msg.angular_velocity.x = 3.1415926 * float(imu_raw_data["gx"]) / (16.4 * 180)
    KeyError: 'gx'
    ```
4.  **Control Failure:** MQTT commands to `/cmd_vel` were ignored or intermittent.

---

#### 🔍 Root Cause: Serial Port Contention

The problem was caused by **Resource Contention** on the serial port `/dev/ttyAMA0`.

Two separate processes were attempting to communicate with the robot hardware simultaneously:

1.  `ros2 run ugv_bringup ugv_driver` (Manual Node)
2.  `ros2 launch ugv_bringup bringup_lidar.launch.py` (Launch File)

Because `bringup_lidar.launch.py` **already includes** the `ugv_driver` node, running both commands meant two programs were "fighting" for the same physical wire. This resulted in:

- **Data Fragmentation:** Bits of data were being "stolen" by one process from the other.
- **Mangled JSON:** The JSON strings sent by the robot were cut in half, making them unreadable.
- **Missing Keys:** When a process received a partial message, essential data like `"gx"` (gyroscope X-axis) was missing, leading to the Python `KeyError`.

---

#### ✅ Solution

The conflict was resolved by **terminating the duplicate process**.

**Correct Procedure:**

1.  Stop all running ROS nodes.
2.  Check for background "zombie" processes: `ps aux | grep python`.
3.  Launch the system using **only** the combined launch file:
    ```bash
    ros2 launch ugv_bringup bringup_lidar.launch.py
    ```

---

**1. Clean the environment variables** (this wipes the "memory" of your native build):

```bash
unset AMENT_PREFIX_PATH
unset PYTHONPATH
unset LD_LIBRARY_PATH
# Reset your PATH to system defaults
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

```

**2. Source ONLY the internal Docker ROS 2:**

```bash
source /opt/ros/humble/setup.bash

```

**3. Verify immediately:**

```bash
which ros2

```

- **Correct Output:** `/opt/ros/humble/bin/ros2`
- **If you see this, proceed to step 4.**

**4. Source your UGV workspace (Carefully):**

```bash
source /home/ws/ugv_ws/install/setup.bash

```

###🚀 Try the launch againNow that `which ros2` points to `/opt/ros/humble/bin/ros2`, try the UGV tool again:

```bash
ros2 launch ugv_description display.launch.py use_rviz:=false

```

## Build the Cyberwave UGV controller locally

build your controller into

```bash
cd cyberwave/cyberwave-backend
source .venv/bin/activate
python manage.py seed_controllers
```

set the ENV variables

```bash
export CYBERWAVE_TWIN_UUID=
export CYBERWAVE_TOKEN=
```

go in cyberwave.com > catalog > UGV Beast > Edit Asset > activate `can_locomote` and `has_joints` > Save Chnages

go into the UGV beast evironment > add UGB Digita;l Twin > click over the asset > `Assign Controller` > chose the controller you developed

---

## Quick Reference: Common Commands

### 🚀 Start Complete System (Recommended)

```bash
# One-command startup for full robot operation
cd /root/ugv_ws
source /root/ugv_ws/install/setup.bash
ros2 launch /root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/master_beast.launch.py robot_id:=robot_ugv_beast_v1
```

### 🔍 Monitor System Status

```bash
# Check all active nodes
ros2 node list

# Monitor velocity commands
ros2 topic echo /cmd_vel

# Monitor joint states
ros2 topic echo /ugv/joint_states

# Check battery status
ros2 topic echo /voltage

# View MQTT bridge logs
ros2 node info /mqtt_bridge_node
```

### 🛠️ Development & Debugging

```bash
# Rebuild MQTT bridge after code changes
cd /root/ugv_ws
rm -rf build/mqtt_bridge install/mqtt_bridge
colcon build --packages-select mqtt_bridge --cmake-args -DBUILD_TESTING=OFF
source install/setup.bash

# Test hardware directly (no MQTT)
ros2 topic pub /ugv/led_ctrl std_msgs/msg/Float32MultiArray "{data: [255, 255]}" -1
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2, y: 0, z: 0}, angular: {x: 0, y: 0, z: 0}}" -1
```

### 📦 Available Launch Files

| File                       | Location                                          | Purpose                               |
| -------------------------- | ------------------------------------------------- | ------------------------------------- |
| **master_beast.launch.py** | `/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/` | Complete system startup (RECOMMENDED) |
| **start_ugv.sh**           | `/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/` | tmux-based multi-terminal startup     |
| **clean_build_mqtt.sh**    | `/root/ugv_ws/src/mqtt_bridge/scripts/ugv_beast/` | Rebuild and restart MQTT bridge       |
