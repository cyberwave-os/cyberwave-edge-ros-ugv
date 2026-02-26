from launch import LaunchDescription
from launch_ros.actions import Node
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
import os


def generate_launch_description():
    """
    Launch the MQTT Bridge node with configuration.
    """
    
    # Declare launch arguments
    log_level_arg = DeclareLaunchArgument(
        'log_level',
        default_value='info',
        description='Logging level (debug, info, warn, error)'
    )
    
    robot_id_arg = DeclareLaunchArgument(
        'robot_id',
        default_value='default',
        description='Robot ID for mapping configuration'
    )
    
    # Get the package share directory
    config_file = os.path.join(
        '/opt/cyberwave-edge-ros',
        'mqtt_bridge',
        'config',
        'params.yaml'
    )
    
    # Create the MQTT Bridge node
    mqtt_bridge_node = Node(
        package='mqtt_bridge',
        executable='mqtt_bridge_node',
        name='mqtt_bridge_node',
        output='screen',
        parameters=[
            config_file,
            {
                'robot_id': LaunchConfiguration('robot_id')
            }
        ],
        arguments=['--ros-args', '--log-level', LaunchConfiguration('log_level')]
    )
    
    return LaunchDescription([
        log_level_arg,
        robot_id_arg,
        mqtt_bridge_node
    ])
