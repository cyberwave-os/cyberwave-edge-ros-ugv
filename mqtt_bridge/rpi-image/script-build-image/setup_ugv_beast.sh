#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[SETUP] Adding ROS 2 Repositories...${NC}"

apt-get update && apt-get install -y curl gnupg2 lsb-release

# 1. Add ROS 2 GPG Key
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# 2. Add ROS 2 Repository to sources list
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# 3. Update and Install Tools
apt-get update
apt-get install -y \
  build-essential \
  cmake \
  git \
  python3-colcon-common-extensions \
  python3-flake8-docstrings \
  python3-pip \
  python3-pytest-cov \
  python3-rosdep \
  python3-setuptools \
  python3-vcstool \
  wget \
  python3-argcomplete

# 4. Initialize rosdep
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    rosdep init
fi
rosdep update

# 5. Build Workspace
WORKSPACE_PATH="/home/pi/ros2_jazzy"
mkdir -p "$WORKSPACE_PATH/src"
cd "$WORKSPACE_PATH"

echo -e "${BLUE}[SETUP] Fetching ROS 2 Jazzy source code...${NC}"
vcs import src < https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos

echo -e "${BLUE}[SETUP] Installing system dependencies...${NC}"
rosdep install --from-paths src --ignore-src -y --skip-keys "fastcdrtester"

echo -e "${BLUE}[SETUP] Compiling (Low RAM mode)...${NC}"
colcon build \
    --merge-install \
    --cmake-args -DCMAKE_BUILD_TYPE=Release \
    --parallel-workers 2

chown -R 1000:1000 "$WORKSPACE_PATH"
echo -e "${GREEN}[SUCCESS] Build complete!${NC}"