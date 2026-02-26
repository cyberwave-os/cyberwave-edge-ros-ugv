# Edge UR7e

## ROS2 installation on Rasperry
Install Ubuntu Noble 24.04 on your Raspberry

[Generic ROS 2 on Raspberri Pi indications](https://docs.ros.org/en/foxy/How-To-Guides/Installing-on-Raspberry-Pi.html)

The fastest and simplest way to use ROS 2 is to use a Tier 1 supported configuration.


### Install ROS 2 Jazzy
[Install ROS 2 Jazzy (Ubuntu Noble 24.04)](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)

#### Set local
```bash
locale  # check for UTF-8

sudo apt update && sudo apt install locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

locale  # verify settings
```
#### Enable required repositories

```bash
sudo apt install software-properties-common
sudo add-apt-repository universe
```

Installing the ros2-apt-source package will configure ROS 2 repositories for your system. Updates to repository configuration will occur automatically when new versions of this package are released to the ROS repositories.

```bash
$ sudo apt update && sudo apt install curl -y
$ export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
$ curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"
$ sudo dpkg -i /tmp/ros2-apt-source.deb
```

#### Install development tools (optional)

```bash
sudo apt update && sudo apt install ros-dev-tools
```

#### Install ROS 2

```bash
sudo apt update
sudo apt upgrade
```


```bash
sudo apt install ros-jazzy-desktop
or
sudo apt install ros-jazzy-ros-base
```

### Setup environment

[Configuring environment](https://docs.ros.org/en/rolling/Tutorials/Beginner-CLI-Tools/Configuring-ROS2-Environment.html#tasks)

Note:     Replace .bash with your shell if you’re not using bash. Possible values are: setup.bash, setup.sh, setup.zsh.

1. Source the setup files
You will need to run this command on every new shell you open to have access to the ROS 2 commands
```bash
source /opt/ros/jazzy/setup.bash
```

    Note:
    The exact command depends on where you installed ROS 2. If you’re having problems, ensure the file path leads to your installation.

2. Add sourcing to your shell startup script
ff you don’t want to have to source the setup file every time you open a new shell (skipping task 1), then you can add the command to your shell startup script:
    ```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
```

3. Check environment variables
    Sourcing ROS 2 setup files will set several environment variables necessary for operating ROS 2. If you ever have problems finding or using your ROS 2 packages, make sure that your environment is properly set up using the following command:

    ```bash
    printenv | grep -i ROS
    ```

    Check that variables like ROS_DISTRO and ROS_VERSION are set.

    ```bash
    ROS_VERSION=2
    ROS_PYTHON_VERSION=3
    ROS_DISTRO=jazzy
    ```

## Install universal Robots ROS2 Driver

[Universal Robots ROS2 Driver](https://github.com/UniversalRobots/Universal_Robots_ROS2_Driver/tree/jazzy)


Make sure that colcon, its extensions and vcs are installed:
```bash
sudo apt install python3-colcon-common-extensions python3-vcstool
```

Create a new ROS2 workspace:
```bash
export COLCON_WS=~/workspace/ros_ur_driver
mkdir -p $COLCON_WS/src
```

Clone relevant packages, install dependencies, compile, and source the workspace by using:
```bash
$ cd $COLCON_WS
$ git clone -b <branch> https://github.com/UniversalRobots/Universal_Robots_ROS2_Driver.git src/Universal_Robots_ROS2_Driver
vcs import src --skip-existing --input src/Universal_Robots_ROS2_Driver/Universal_Robots_ROS2_Driver-not-released.${ROS_DISTRO}.repos
rosdep update
rosdep install --ignore-src --from-paths src -y
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash
```


Possible error 
```bash
--- stderr: ur_controllers                          
CMake Error at CMakeLists.txt:11 (find_package):
  By not providing "Findcontroller_interface.cmake" in CMAKE_MODULE_PATH this
  project has asked CMake to find a package configuration file provided by
  "controller_interface", but CMake did not find one.
  Could not find a package configuration file provided by
  "controller_interface" with any of the following names:
    controller_interfaceConfig.cmake
    controller_interface-config.cmake
  Add the installation prefix of "controller_interface" to CMAKE_PREFIX_PATH
  or set "controller_interface_DIR" to a directory containing one of the
  above files.  If "controller_interface" provides a separate development
  package or SDK, be sure it has been installed.
---
Failed   <<< ur_controllers [1.14s, exited with code 1]
Summary: 2 packages finished [52.6s]
  1 package failed: ur_controllers
  1 package had stderr output: ur_controllers
  3 packages not processed
```

**To fix your installation, you need to:**

1. **Initialize rosdep:**
```bash
sudo rosdep init
rosdep update
```

2. **Import the missing dependencies with the CORRECT filename:**
```bash
cd /home/edgeros/workspace/ros_ur_driver
vcs import src --skip-existing --input src/Universal_Robots_ROS2_Driver/Universal_Robots_ROS2_Driver.jazzy.repos
```

3. **Install any remaining system dependencies:**
```bash
rosdep install --ignore-src --from-paths src -y
```

4. **Rebuild the workspace:**
```bash
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release
```

5. **Source the workspace:**
```bash
source install/setup.bash
```


### Driver startup

For starting the driver it is recommended to start the ur_control.launch.py launchfile from the ur_robot_driver package. It starts the driver, a set of controllers and a couple of helper nodes for UR robots. The only required arguments are the ur_type and robot_ip parameters.

```bash
ros2 launch ur_robot_driver ur_control.launch.py ur_type:=<UR_TYPE> robot_ip:=<IP_OF_THE_ROBOT> launch_rviz:=true
```
i.e.
```bash
ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur7e robot_ip:=192.168.100.44
```
Other important arguments are:
* `kinematics_params_file` (default: None) - Path to the calibration file extracted from the robot, as described in Extract calibration information.

* `use_mock_hardware` (default: false ) - Use simple hardware emulator from ros2_control. Useful for testing launch files, descriptions, etc.

* `headless_mode` (default: false) - Start driver in Headless mode.

* `launch_rviz` (default: true) - Start RViz together with the driver.

* `initial_joint_controller` (default: scaled_joint_trajectory_controller) - Use this if you want to start the robot with another controller.


## Network configuration

The robot IP of the can be retrieved and changed from the menu in the UR’s teach pendant main screen.

change the ur7 ip to 192.168.100.44

EXPLAIN HOW TO SET IP ADDRESS IN THE UR7

![Set Ip pendant](img/set_ip.jpg)


for this project the raspberry are using the 192.168.100.160 and the UR7 is using the 192.168.100.44

keep in mind that is mandatory to use a subnet differet to 192.168.0.xxx so we used the 192.168.100.xxx

or something like that 

### Steps to Set Raspberry Static IP using Netplan

#### Identify the Netplan Configuration File

Netplan configuration files are usually found in the `/etc/netplan/` directory and have a `.yaml` extension.

```bash
ls /etc/netplan/
```

###  Edit the Netplan Configuration File

Open the identified `.yaml` file for editing using `sudo nano`:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

### Configure the $\mathbf{eth0}$ Interface

Edit the file to configure the $\mathbf{eth0}$ interface with the static IP $\mathbf{192.168.100.160}$. Make sure the formatting and indentation follow the YAML syntax exactly (spaces, not tabs).

**Example Netplan Content:**

```yaml
# Disable the cloud-init config that's overriding with DHCP
sudo mv /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.disabled

# Remove wlan0 from the static config (to stop getting a second IP)
sudo tee /etc/netplan/01-static-eth0.yaml << 'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.100.160/24]
      # gateway4: 192.168.100.1
      # nameservers:
      #   addresses: [8.8.8.8, 8.8.4.4]
EOF

# Also remove/disable the other conflicting file if it has eth0 config
sudo mv /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.disabled

# Fix permissions and apply
sudo chmod 600 /etc/netplan/01-static-eth0.yaml
sudo netplan apply

# Verify
hostname -I
```

**Key Changes:**

  * **`eth0:`**: Specifies the Ethernet interface.
  * **`dhcp4: no`**: Disables dynamic IP assignment for IPv4.
  * **`addresses: [192.168.100.160/24]`**: Sets the static IP address. The `/24` suffix sets the subnet mask to **$255.255.255.0$**.
  * **Remove Gateway/Nameservers (Recommended for Dedicated Link):** If your Ubuntu machine is only connected to the UR robot via a direct cable or local switch, you can omit the `gateway4` and `nameservers` lines.


### Apply the Netplan Configuration

Apply the new configuration using the `netplan apply` command:

```bash
sudo netplan apply
```

### Verification
Check the $\mathbf{eth0}$ interface
```bash
ip addr show eth0
```
You should see the line: `inet 192.168.100.160/24`

### Test

ping the ur7
```
 ping 192.168.100.44
 ```

## Install URCaps on the Robot
[Installing the URCap](https://www.universal-robots.com/manuals/EN/HTML/SW5_19/Content/prod-myurm/myurm-ig-install-urcap-how.htm)
1. Install External Control URCap

Download the URCap from the Universal Robots ROS 2 driver repository
On the teach pendant: Settings → System → URCaps
Install the externalcontrol-1.0.5.urcap file
Restart the robot


What is a URCap?
URCap (Universal Robots Capability) is a plugin system for UR robots that extends their functionality. The External Control URCap specifically allows external computers (like your Raspberry Pi) to control the robot in real-time through ROS 2.
Step-by-Step Installation Guide


find the exact URCap version from your Raspberry Pi:
```bash
cd /workspace/ros_ur_driver/src/Universal_Robots_ROS2_Driver/ur_robot_driver/resources
```
or

```bash
# search for the URCap file directly
find . -name "*.urcap" -type f
```

output:
```bash
./resources/externalcontrol-1.0.5.urcap
./resources/rs485-1.0.urcap
```


Step 1: Download the URCap File
Option A: Download from GitHub
make sure you are downloding the same version

or

On your PC:
1. from your pc get via scp the .urcap files 
```bash
brew install scp
# Transfer to your computer using SCP
# On your PC, run:
scp "edgeros@192.168.0.160:~/workspace/ros_ur_driver/src/Universal_Robots_ROS2_Driver/ur_robot_driver/resources/*.urcap" ~/Downloads/
```

2. Copy the URCap file to the USB drive:
Insert a USB flash drive into your computer
Format it as FAT32 if needed:

* Windows: Right-click drive → Format → Select FAT32
* Mac: Disk Utility → Erase → Select MS-DOS (FAT)
* Linux: sudo mkfs.vfat /dev/sdX1 (replace sdX1 with your drive)

Simply drag and drop the .urcap file to the root of the USB drive
Or copy it to a folder on the USB drive




3. Connect USB to Robot
Physical connection:

Locate the USB port on the teach pendant:

Usually on the back or side of the teach pendant
Some UR models have USB ports on the control box as well


Insert the USB drive into the teach pendant's USB port
Wait a moment for the robot to recognize the USB drive

4. Install from USB via Teach Pendant
On the teach pendant screen:


**Navigate to URCaps Menu:**
1. On the teach pendant screen, tap the **hamburger menu** (☰) in the top-right corner
2. Select **"Settings"**
3. Go to **"System"** tab
4. Select **"URCaps"**
Tap hamburger menu (☰) → Settings → System → URCaps
Tap the "+" button or "Install" button
A file browser will appear showing:

Internal storage
USB drive (usually labeled as "USB" or "External Storage")


Navigate to the USB drive:

Tap on the USB drive icon
Browse to where you placed the .urcap file

**Install the URCap:**
1. You'll see a list of installed URCaps (if any)
2. Tap the **"+" button** or **"Install"** button at the bottom
3. Navigate to your USB drive
4. Select the `externalcontrol-X.X.X.urcap` file
5. Confirm the installation
6. Wait for the installation to complete (usually takes 10-30 seconds)

Select the URCap file:

Tap on externalcontrol-X.X.X.urcap
Confirm installation


Wait for installation to complete (10-30 seconds)
Remove the USB drive after installation
Restart the robot:

Hamburger menu → Shutdown → Restart

### **Step 5: Verify Installation**

After restart, check if it's installed:
1. Go to **Settings → System → URCaps**
2. You should see **"External Control"** in the list with version number
3. It should show as **"Active"** or have a green indicator

at the end yopu should see something like this:
![Install urcp pendant](img/install_urcp_enternal_control.jpg)


## Use External Control in a Program**

Now you can create a robot program that uses it:

1. **Create a new program:**
    1. Tap **"Program"** tab at the bottom
    2. Create a new program or open existing one
    3. In the program tree on the left:
    - Look for **"URCaps"** or **"Structure"** section
    - You should now see **"External Control"** listed
    4. **Drag "External Control"** into your program sequence

2. **Add External Control node:**
   - In the program tree, tap **"Structure"** tab (or "URCaps")
   - You should now see **"External Control"** as an option
   - Drag it into your program sequence

3. **Configure External Control:**
   - Tap on the External Control node
   - Set **"Host IP"** to your Raspberry Pi's IP: `192.168.1.100`
   - Set **"Custom Port"** (optional, default is 50002)
   - Leave other settings as default

4. **Complete the program:**
```
   Program
   ├── BeforeStart
   ├── Robot Program
   │   └── External Control (192.168.1.100)
```
![External control program](img/external_control_program.jpg)

### Configure External Control Settings**

Click on the **"External Control"** node you just added:

**Critical settings:**
- **Host IP:** `192.168.0.100` (your Raspberry Pi's IP address)
- **Custom Port:** `50002` (default, usually don't change)
- **Name:** Leave as default

**Important:** The Host IP must exactly match your Raspberry Pi's IP address!

to edit it you must go in Istanlation tab > URCap > External Control and then set Host Ip and Host name

![External control program](img/set_ip.jpg)

### Save the Program**

1. Tap the **"Save"** button
2. Name it something like `ROS2_External_Control` or `RPi_Control`

### Enable Remote Control (If Needed)**

Some UR models require enabling remote control:

1. Go to **Settings** → **System** → **Remote Control**
2. Enable **"Enable Remote Control"** if available
3. Set appropriate permissions

### Check Safety Configuration**

1. Go to **Installation** → **Safety**
2. Verify that the safety configuration allows external control
3. Ensure no safety limits will prevent motion

### Run the Program**

**This is the crucial step that people often forget:**

1. Make sure the program with External Control is loaded
2. The robot should be in **"Normal"** mode (check status in top-right)
3. **Press the PLAY button** ▶️ to start the program

![load program](img/load_program.jpg)


4. The robot will enter the External Control node and display something like:
   - **"Waiting for external control..."**
   - **"Connecting to 192.168.0.100:50002"**

![started program](img/started_program.jpg)

**The program must be running AFTER launch the ROS 2 driver on the Raspberry Pi!**

### **Step 9: Verify Connection Status**

Once the program is running:
- The teach pendant will show it's waiting for external control
- **Now** launch the ROS 2 driver on your Raspberry Pi
- The robot should connect and you'll see "Connected" on the teach pendant

## Common Issues

**"External Control not visible in program"**
- URCap not installed or robot not restarted after installation

**"Cannot connect to host"**
- Wrong IP address in External Control settings
- Raspberry Pi not reachable from robot (check network)

**"Program stops immediately"**
- External Control node needs ROS 2 driver running to stay active
- Both must be running simultaneously

## Order of Operations

The correct sequence is:

1. **Robot:** Configure network and install URCap
2. **Raspberry Pi:** Launch ROS 2 driver
3. **Robot:** Create and start program with External Control 
4. **Both:** Connection established automatically

on the raspberry
```bash
cd $COLCON_WS
source install/setup.bash
# Launch the driver
ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur7e robot_ip:=192.168.100.44 launch_rviz:=false
```


errors and throubleshouting 
---

## 🛑 What Is Not Working (Key Problems)

### 1. ⚙️ Kinematics Calibration Mismatch (Critical for Accuracy)

This is the most critical functional error:

> `[ros2_control_node-1] [ERROR] [1763713598.141487016] [URPositionHardwareInterface]: The **calibration parameters** of the connected robot don't match the ones from the given kinematics config file. Please be aware that this can lead to **critical inaccuracies of tcp positions**. Use the ur_calibration tool to extract the correct calibration from the robot and pass that into the description.`

* **Problem:** The Universal Robot is highly precise because each arm is individually measured and calibrated at the factory. The **kinematics file** (URDF/XACRO) being used by your ROS 2 driver **does not match** the specific calibration data (`calib_12788084448423163542`) found on your physical UR7e controller.
* **Impact:** The inverse and forward kinematics calculations performed by the ROS motion planning stack (like MoveIt 2) will be **inaccurate**. If you command the robot to move to a specific TCP pose, the end-effector will likely miss the target position.

---

## 🔧 Suggested Fixes and Documentation

### A. Kinematics Calibration Fix (Accuracy)

This must be corrected for any accurate work with TCPs.

| Step | Action | Documentation Note |
| :--- | :--- | :--- |
| **1. Extract Calibration** | Use the `ur_calibration` tool provided by the driver package to extract the unique calibration data from the robot controller (using the Dashboard Server connection). | **Command:** See `ur_calibration` tool documentation. This produces a YAML or JSON file with the robot's unique kinematics parameters. |
| **2. Update ROS 2 Description** | Configure your ROS 2 launch file to include a path to the newly generated calibration file. | **Launch Argument:** Add a parameter like `kinematics_config:="/path/to/your_ur7e_calib.yaml"` to the relevant launch file arguments. |
| **3. Verify** | Relaunch the driver (`ur_control.launch.py`). The specific **ERROR** message about calibration mismatch should disappear. | **Success Criterion:** The log should show `Calibration checksum: 'calib_xxxxxxxxxxxxxxxxx'.` but **no ERROR** that the parameters don't match. |



### 3\. 🏗️ Build the Workspace

```bash
cd $COLCON_WS
colcon build --packages-select ur_calibration
```

  * The `--packages-select ur_calibration` flag speeds up the process by only building the package you just added.

### 4\. ✅ Source the New Setup

```bash
source install/setup.bash
```

### 5\. 🔬 Rerun the Calibration Command

Now that the package is built and sourced, you should be able to run the calibration command without the "Package not found" error:

```bash
ros2 launch ur_calibration calibration_correction.launch.py robot_ip:=192.168.100.44 target_filename:="${HOME}/ur7e_factory_calibration.yaml"
```

If you still encounter issues, check if the package name is correct using `ros2 pkg prefix ur_calibration`. If it returns a path, the package is installed, and the issue might be related to your environment sourcing.


⚠️ Important Prerequisites (Recap)
Before the robot will execute commands, ensure the following are still true:

UR Program Running: The program containing the External Control URCap node must be loaded on the Teach Pendant, and the robot must be in Play/Run mode.

Safety Mode: The robot should be in Normal operating mode (not Protective Stop or E-Stop).

If the launch command runs without the calibration error, you can then proceed to send movement commands, such as running the test_joint_trajectory_controller again.



## Set the UR7 initial state
By default, the robot’s pose is checked for being close to a predefined configuration in order to make sure that the robot doesn’t perform any large, unexpected motions. This configuration is specified in the config/test_goal_publishers.yaml config file of the ur_robot_driver package. The joint values are
```
shoulder_pan_joint: 0
shoulder_lift_joint: -1.57
elbow_joint: 0
wrist_1_joint: -1.57
wrist_2_joint: 0
wrist_3_joint: 0
```
set this position in ragiant.


that corepond to the following degrees
```
shoulder_pan_joint: 0
shoulder_lift_joint: 90
elbow_joint: 0
wrist_1_joint: 90
wrist_2_joint: 0
wrist_3_joint: 0
```
so basically the valus above must be setted as ur7 initial point

![ur7 start pos pendant](img/start_pos.jpg)

in order to do that you should go to Move click on the value


![Set ur7 pos values pendant](img/set_manual_values.jpg)

the click the green check and push "move to new position"

![Mov ur7 to pos pendant](img/move_to_pos.jpg)






# The official test script:
now you can try the official test script 

 Launch the driver on your hardware (Pi) with that controller mode.
   Example:

   ```bash
   ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur7e robot_ip:=192.168.1.10 initial_joint_controller:=scaled_joint_trajectory_controller
   ```

3. From your Python script (on the Pi) send `FollowJointTrajectory` action goals exactly like you did with your adaptive script — but ensure the `joint_names` correspond to the correct controller and the action target is something like `/scaled_joint_trajectory_controller/follow_joint_trajectory`.
   The docs example shows:

   > `$ ros2 run ur_robot_driver example_move.py`
   > It waits for action server on `scaled_joint_trajectory_controller/follow_joint_trajectory` ([docs.universal-robots.com][3])

4. On the teach pendant / UR side ensure the “External Control” program is loaded and running (as usual) so the robot can accept trajectories.

5. Verify controller interface:

   ```bash
   ros2 control list_controllers
   ```

   and ensure `scaled_joint_trajectory_controller` or `passthrough_trajectory_controller` is **active** and in state `running`.

---





so run this
```bash
ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur7e robot_ip:=192.168.1.10 initial_joint_controller:=scaled_joint_trajectory_controller
# in another terminal 
ros2 run ur_robot_driver example_move.py
```

if it works we can pass to 



## cyberwave-ros2 edge conf and running

copy mqtt-bridge into ros_ur_driver
```
 git clone https://github.com/cyberwave-os/cyberwave.git

cp -r /home/edgeros/cyberwave/cyberwave-edges/cyberwave-ros2/mqtt_bridge /home/edgeros/workspace/ros_ur_driver/src/
```









## Clean Installation Commands 🧹

Here are the commands to do a complete clean installation:

```bash
# 1. Navigate to workspace root
cd /home/edgeros/workspace/ros_ur_driver

# 2. Clean all mqtt_bridge artifacts
rm -rf build/mqtt_bridge install/mqtt_bridge log/latest_build/mqtt_bridge

# 3. Clean any stray build artifacts inside the source directory
rm -rf src/mqtt_bridge/build src/mqtt_bridge/install src/mqtt_bridge/log

cd /home/edgeros/workspace/ros_ur_driver && rm -rf install/mqtt_bridge build/mqtt_bridge && echo "Deleted install/mqtt_bridge and build/mqtt_bridge"

# 4. Install Python dependencies (if not already installed)
sudo apt update
sudo apt install -y python3-paho-mqtt python3-yaml
# OR with pip:
# pip3 install --user paho-mqtt pyyaml

# 5. Build the mqtt_bridge package
colcon build --packages-select mqtt_bridge

# 6. Source the workspace
source install/setup.bash

# 7. Verify installation
ros2 pkg prefix mqtt_bridge
# Should output: /home/edgeros/workspace/ros_ur_driver/install/mqtt_bridge

# 8. Test the node (Ctrl+C to stop)
ros2 run mqtt_bridge mqtt_bridge_node

# 9. Or launch with the launch file
ros2 launch mqtt_bridge bridge_launch.py
```

### To Rebuild Everything from Scratch (if needed):

```bash
cd /home/edgeros/workspace/ros_ur_driver

# Remove all build artifacts
rm -rf build install log

# Clean source directory
rm -rf src/mqtt_bridge/build src/mqtt_bridge/install src/mqtt_bridge/log

# build only specific packages (UR driver + mqtt_bridge):
cd /home/edgeros/workspace/ros_ur_driver && colcon build --packages-up-to mqtt_bridge ur_robot_driver ur_calibration --allow-overriding control_msgs control_toolbox realtime_tools

# Source the workspace
source install/setup.bash
```








## Two Versions of Files

### 1. **Source Files** (where you edit):
```
/home/edgeros/workspace/ros_ur_driver/src/mqtt_bridge/config/mappings/robot_arm_v1.yaml
```
- This is the **original** file in your source code
- **This is where you make changes** when you want to modify configurations
- Under version control (git)

### 2. **Installed Files** (what ROS 2 uses):
```
/home/edgeros/workspace/ros_ur_driver/install/mqtt_bridge/share/mqtt_bridge/config/mappings/robot_arm_v1.yaml
```
- This is a **copy** created during `colcon build`
- **This is what ROS 2 actually uses** at runtime
- Gets regenerated every time you run `colcon build`

## Important Workflow 🔄

```bash
# 1. Edit source file
nano src/mqtt_bridge/config/mappings/robot_arm_v1.yaml

# 2. Rebuild to copy changes to install directory
colcon build --packages-select mqtt_bridge

# 3. Source the workspace (if not already done)
source install/setup.bash

# 4. Now ROS 2 will use your updated configuration
ros2 launch mqtt_bridge bridge_launch.py
```

### Why This Design?

- **Separation**: Keeps source code clean and separate from built artifacts
- **Safety**: You can delete `install/` and `build/` anytime and rebuild from source
- **Multi-package**: Allows multiple packages to be built and installed together

### Quick Tip 💡

If you're making frequent config changes and don't want to rebuild every time, you can also edit the installed file directly for **testing purposes only**:

```bash
# Quick test (changes lost on next build!)
nano install/mqtt_bridge/share/mqtt_bridge/config/mappings/robot_arm_v1.yaml
```

PAY ATEENTION each time you want to run the mqtt bridge you must run `source install/setup.bash` 
```bash
cd /home/edgeros/workspace/ros_ur_driver
source install/setup.bash
ros2 launch mqtt_bridge bridge_launch.py
```

## Build ros_bridge

```bash
cd /home/edgeros/workspace/ros_ur_driver
rm -rf install/mqtt_bridge build/mqtt_bridge
source /opt/ros/jazzy/setup.bash
colcon build --packages-select mqtt_bridge --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash
```

## Running UR7e Teleoperation

This guide explains how to set up remote teleoperation of the UR7e robot via ROS 2 and MQTT bridge.

### Prerequisites

- SSH access to the EdgeOS device
- UR7e robot powered on and connected to the network (192.168.100.44)
- Factory calibration file located at `~/ur7e_factory_calibration.yaml`

### Step 1: SSH Connection to the Edge Device

```bash
ssh edgeros@192.168.100.160
```

**Note**: Fixed the IP address (was `198.168.100.160`, should be `192.168.100.160`)

### Step 2: Launch the UR7e Robot Driver

Open **Terminal 1** and run:

```bash
# Navigate to workspace
cd /home/edgeros/workspace/ros_ur_driver

# Source ROS 2 and workspace
source /opt/ros/jazzy/setup.bash
source install/setup.bash

# Launch UR7e driver
ros2 launch ur_robot_driver ur_control.launch.py \
  ur_type:=ur7e \
  robot_ip:=192.168.100.44 \
  launch_rviz:=false \
  kinematics_params_file:="${HOME}/ur7e_factory_calibration.yaml"
```

### Step 3: Configure the UR7e Pendant

On the UR7e teach pendant:

1. Navigate to the **Execute** page
2. Select **Load Program**
3. Choose the `remote_control_ros2` program
4. Press **Play** to start the program

This program enables remote control and opens the ROS 2 connection exclusively for the edge device at IP `192.168.100.160:50002`.

### Step 4: Verify Environment Variables

Check that the Cyberwave credentials are correctly configured in `/home/edgeros/workspace/ros_ur_driver/.env`:

```bash
# Cyberwave API Token for MQTT Bridge
CYBERWAVE_TOKEN=your-api-token-here
# Digital Twin UUID
CYBERWAVE_TWIN_UUID=your-twin-uuid-here

# Optional: Topic prefix (empty string recommended for SDK topics)
# MQTT Config
CYBERWAVE_MQTT_BROKER=mqtt.cyberwave.com
CYBERWAVE_MQTT_PORT=1883
CYBERWAVE_MQTT_USERNAME=mqttcyb
CYBERWAVE_MQTT_PASSWORD=mqttcyb231

# Optional: Environment and Edge identifiers
CYBERWAVE_EDGE_UUID=edge-device-001
CYBERWAVE_ENVIRONMENT="production"
```

### Step 5: Launch the MQTT Bridge

Open **Terminal 2** and run:

```bash
# Navigate to workspace
cd /home/edgeros/workspace/ros_ur_driver

# Switch to scaled joint trajectory controller
ros2 control switch_controllers \
  --deactivate forward_position_controller \
  --activate scaled_joint_trajectory_controller

# Source ROS 2 and workspace
source /opt/ros/jazzy/setup.bash
source install/setup.bash

# Export environment variables
set -a; source .env; set +a

# Launch the MQTT bridge
ros2 launch mqtt_bridge bridge_launch.py
```

#### Usefull ros2 commands

first of all install the package:
```bash
sudo apt-get install ros-${ROS_DISTRO}-ros2controlcli
```
When the driver is started, you can list all loaded controllers using the  command. For this, 
```bash
ros2 control list_controllers
```
For all other arguments, please see
```bash
ros2 launch ur_robot_driver ur_control.launch.py --show-args
```

get actual joint state
```bash
ros2 topic echo /joint_states --once
```



### Set the Vacuum

## If the package isn't found

You may need to source your workspace or install the package:

```bash
# Source your workspace
source ~/workspace/ros_ur_driver/install/setup.bash

# Or install the ur_dashboard_msgs package
sudo apt install ros-${ROS_DISTRO}-ur-dashboard-msgs
```


## Vacuum Digital Output control

in works with the pendant program ros2_digital_pin_vacuum_control
```bash
# Turn vacuum ON
ros2 service call /io_and_status_controller/set_io ur_msgs/srv/SetIO "{fun: 1, pin: 0, state: 1.0}"

# Turn vacuum OFF
ros2 service call /io_and_status_controller/set_io ur_msgs/srv/SetIO "{fun: 1, pin: 0, state: 0.0}"
```


# Send any physical joint command

UR7e pendant program to be able to run the vacuum
`ros2_digital_pin_vacuum_control` contain the business logic to control the vacuum.

![Set Ip pendant](img/vacuum_program.jpg)

```bash
# Turn vacuum ON
mosquitto_pub -h mqtt.cyberwave.com  -p 1883  -u mqttcyb  -P mqttcyb231 -t "cyberwave/joint/8a7e87e6-e47c-45e8-8b68-69d8101ef846/update" \
-m '{"joint_name":"ee_fixed_joint","joint_state":{"position":0.5,"velocity":0,"effort":0}}'

# Turn vacuum OFF
mosquitto_pub -h mqtt.cyberwave.com  -p 1883  -u mqttcyb  -P mqttcyb231 -t "cyberwave/joint/8a7e87e6-e47c-45e8-8b68-69d8101ef846/update" \
-m '{"joint_name":"ee_fixed_joint","joint_state":{"position":-1,"velocity":0,"effort":0}}'


| Position Range | State | Digital Output 0 |
|---------------|-------|------------------|
| **-3.142 to 0.0 rad** | OFF | LOW (0.0) |
| **0.0 to 3.142 rad** | ON | HIGH (1.0) |



pkill -9 -f "ur_robot_driver"

### Running the URScript Program in Headless Mode

Given the existing steps, here is the most straightforward way to run your custom URScript program:

#### Option 1: Using the Existing Teach Pendant Setup (Recommended for your steps)

The guide already instructs you to load the `remote_control_ros2` program (Step 3).

1.  **Modify the `remote_control_ros2` Program:**

      * On the UR7e Teach Pendant, open the `remote_control_ros2` program.
      * **Crucially:** Modify the program flow to **immediately call/run** the logic contained in the `ros2_digital_pin_vacuum_control.urp` file. This ensures your vacuum logic is active while the ROS connection is established.

2.  **Follow the Provided Guide (Steps 1-3):**

      * **Step 2:** Launch the **ROS driver** on the Edge Device (`ur_control.launch.py`).
      * **Step 3:** Manually load the modified `remote_control_ros2` program on the Teach Pendant and press **Play**.
      * The robot is now in "remote control mode" *and* running your vacuum logic, allowing the ROS driver to take control.

-----




Terminal 1
```bash
# Navigate to workspace
cd /home/edgeros/workspace/ros_ur_driver

# Source ROS 2 and workspace
source /opt/ros/jazzy/setup.bash
source install/setup.bash

# Launch UR7e driver in headless mode
ros2 launch ur_robot_driver ur_control.launch.py \
  ur_type:=ur7e \
  robot_ip:=192.168.100.44 \
  launch_rviz:=false \
  kinematics_params_file:="${HOME}/ur7e_factory_calibration.yaml" \
  external_control_urcap:=true
  robot_controller:=scaled_joint_trajectory_controller


# Switch to scaled joint trajectory controller
ros2 control switch_controllers \
  --deactivate forward_position_controller \
  --activate scaled_joint_trajectory_controller
```

Terminal 2
```bash
# Navigate to workspace
cd /home/edgeros/workspace/ros_ur_driver

# Source ROS 2 and workspace
source /opt/ros/jazzy/setup.bash
source install/setup.bash
# Export environment variables
set -a; source .env; set +a

#Ensure the robot is powered on and brakes are released:
# Turn On the UR7
ros2 service call /dashboard_client/power_on std_srvs/srv/Trigger "{}"
# Release the brakes
ros2 service call /dashboard_client/brake_release std_srvs/srv/Trigger "{}"


# load the program `ros2_digital_pin_vacuum_control.urp`
ros2 service call /dashboard_client/load_program ur_dashboard_msgs/srv/Load "{filename: 'ros2_digital_pin_vacuum_control.urp'}"

# Play
ros2 service call /dashboard_client/play std_srvs/srv/Trigger "{}"
```

This method fully automates the process, making it truly "headless" for subsequent startups, but **requires the robot to be running a program that enables the remote connection (External Control URCap) before the driver can send commands.**

```bash
# Export environment variables
set -a; source .env; set +a

# Launch the MQTT bridge
ros2 launch mqtt_bridge bridge_launch.py
```

True Headless Start (Automated, requires specific ROS service calls)

To completely eliminate the need to press **Play** on the pendant, you would typically use a tool like the **Dashboard Client** (which is not explicitly launched in your steps but is part of the overall toolset):

1.  **Ensure the Robot is in Remote Control Mode** (This is often a setting in the Robot's Installation configuration).

2.  **Launch the ROS Driver** (Your Step 2).

3.  **Use the Dashboard Client Service:** After the ROS driver is launched, use the `dashboard_client` (or similar ROS service) to remotely load and play the desired program.

    * **Program Name:** You would call the program that contains the **External Control URCap** and your vacuum logic. In your case, this is likely the `remote_control_ros2` program **modified to include the vacuum logic**.
    * **ROS Service Call (Conceptual):**



### Install Cyberwave SDK

Install [Cyberwave SDK](https://github.com/cyberwave-os/cyberwave-python) in order to enable the digital twin update from the edge joints data.

```bash
source .venv/bin/activate

python3 -m venv ".venv"

pip install cyberwave
```

to publish in upstream from ros-to-mqtt enable the `params.yaml` args:
```bash
ros2 run mqtt_bridge mqtt_bridge_node --ros-args --params-file install/mqtt_bridge/share/mqtt_bridge/config/params.yaml --log-level mqtt_bridge_node:=debug
```


```bash
cd /home/edgeros/workspace/ros_ur_driver
colcon build --packages-select mqtt_bridge
source install/setup.bash
ros2 run mqtt_bridge mqtt_bridge_node --ros-args --params-file install/mqtt_bridge/share/mqtt_bridge/config/params.yaml
```

```bash
cd cyberwave-sdks/cyberwave-python/examples
python ur7-santas-little-helper.py
```