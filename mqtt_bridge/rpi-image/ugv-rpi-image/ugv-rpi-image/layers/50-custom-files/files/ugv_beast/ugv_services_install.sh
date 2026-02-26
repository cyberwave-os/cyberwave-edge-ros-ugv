#!/bin/bash
# UGV Services Installation Script
# This is a PLACEHOLDER - replace with your actual ugv_services_install.sh
#
# Expected location in image:
#   /home/ubuntu/ws/ugv_ws/ugv_services_install.sh

set -e

echo "🚀 Installing UGV services..."

# Example: Create systemd service for UGV
# Uncomment and customize as needed

# sudo tee /etc/systemd/system/ugv.service > /dev/null <<EOF
# [Unit]
# Description=UGV ROS 2 Service
# After=network.target
# 
# [Service]
# Type=simple
# User=ubuntu
# WorkingDirectory=/home/ubuntu/ws/ugv_ws
# Environment="ROS_DOMAIN_ID=0"
# Environment="UGV_MODEL=ugv_beast"
# ExecStart=/home/ubuntu/ws/ugv_ws/start_ugv.sh
# Restart=on-failure
# RestartSec=10
# 
# [Install]
# WantedBy=multi-user.target
# EOF

# sudo systemctl daemon-reload
# sudo systemctl enable ugv.service

echo "✅ UGV services installed!"
echo "   Start with: sudo systemctl start ugv.service"
echo "   Status:     sudo systemctl status ugv.service"
