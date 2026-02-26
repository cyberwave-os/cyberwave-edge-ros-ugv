#!/usr/bin/env python3
"""
UGV Beast Master Launch File
This is a PLACEHOLDER - replace with your actual master_beast.launch.py

Expected location in image:
  /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/launch/master_beast.launch.py
"""

from launch import LaunchDescription
from launch_ros.actions import Node
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration

def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument(
            'use_sim_time',
            default_value='false',
            description='Use simulation clock'
        ),
        
        # Example nodes - replace with your actual configuration
        Node(
            package='ugv_base_node',
            executable='ugv_base_node',
            name='ugv_base_node',
            parameters=[{
                'use_sim_time': LaunchConfiguration('use_sim_time'),
                'model': 'ugv_beast'
            }]
        ),
        
        # Add your other nodes here
    ])
