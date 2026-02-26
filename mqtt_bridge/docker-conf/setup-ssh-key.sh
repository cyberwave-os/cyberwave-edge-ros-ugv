#!/bin/bash
# Setup SSH key for ngrok-edgeugv-docker host
# Run this script to configure SSH key authentication

HOST="192.168.0.144"
PORT="23"
USER="root"
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDWJ5K1rvUFSAERS4+v1YlIHqXg4inr/6halq/a3LBqzLHxWaNfY0jxSpeWH793mgf3LS4uiiorsFLVSgQ+fr4VwwfC2jhdE5hYvcwyh+gzfLX20KyJQDKPUfm2jgCCY1C6hehIs9+ioNUdN2hkKXNgTMtB7LpEy9Y92GdvXK/qi+iqkvDA6Jh3TzjD3drWxZpnc8NBpCwA07bNUonX38RTq0RdtPpuSHPyUeA2qRupLAdaBtUJdFyav2KzP7IIlq+9sAZhJmB+Q3R4JF4l/7Sl+gVHE51p1dmysBxKtDuS0Y6OyT3/UDUO3PDuzkxXOmf4uQEohqIWhThlOKNHDe3XDx1HaLeCn8Czci7/fFDbAnqkPdd9XbisJhTM7bluebLPp2C6NCeBDJtRJ4hE/xYpxljFCVxl9DQ5mkd6EjPUq42vKDe/G5msBhGsVuEPhmHrHOE9ZNpaurecdLYUXWkl5PRYZYn7ZFzT2PvLcSlRIBInqHiUdQ0ZtQ38B/YG7iXiLMeKp6JYrgx+3STsZsmhhYloqkT5A200wzDtDtZskItpA/g9y6dKIEOjBJmXgZontCg1vewzZgzWh5xpeCC/3dlI0wWrgeUlfsYm/9uyDoPHst+iWR7z232In5TPCMeloraPocwksvOtxiEsoOP40M2qyCgWQS/rHoKV2kwyOw== philiptambe@Philips-MacBook-Pro.local"

echo "Setting up SSH key for $USER@$HOST:$PORT"
echo ""
echo "Method 1: Using ssh-copy-id (easiest)"
echo "----------------------------------------"
echo "ssh-copy-id -p $PORT -i ~/.ssh/id_rsa.pub $USER@$HOST"
echo ""
echo "Method 2: Manual via SSH (if password auth works)"
echo "----------------------------------------"
echo "ssh -p $PORT $USER@$HOST \"mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBLIC_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys\""
echo ""
echo "Method 3: If it's a Docker container (from the host machine)"
echo "----------------------------------------"
echo "Find the container name/ID first:"
echo "docker ps | grep ugv"
echo ""
echo "Then run (replace CONTAINER_NAME):"
echo "docker exec -it CONTAINER_NAME bash -c \"mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUBLIC_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys\""
echo ""
echo "After setup, test with:"
echo "ssh -p $PORT -i ~/.ssh/id_rsa $USER@$HOST"
