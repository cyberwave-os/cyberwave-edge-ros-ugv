#!/usr/bin/env python3
import os
import yaml
from ament_index_python.packages import get_package_share_directory, PackageNotFoundError
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, SetEnvironmentVariable, LogInfo
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch.conditions import IfCondition
from launch_ros.actions import LoadComposableNodes, Node, ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

# Helper to check if a package exists
def package_available(package_name):
    try:
        get_package_share_directory(package_name)
        return True
    except PackageNotFoundError:
        return False

def generate_launch_description():
    # Ensure we have a valid working directory to avoid Fast DDS XMLPARSER errors
    # Fast DDS tries to call getcwd() which fails if the CWD was deleted
    home_dir = os.path.expanduser('~')
    try:
        os.getcwd()
    except (FileNotFoundError, OSError):
        os.chdir(home_dir)
    
    # 1. Paths to packages and configurations
    ugv_bringup_dir = get_package_share_directory('ugv_bringup')
    ugv_vision_dir = get_package_share_directory('ugv_vision')
    ugv_description_dir = get_package_share_directory('ugv_description')
    mqtt_bridge_dir = get_package_share_directory('mqtt_bridge')
    
    # Check for optional packages
    has_ldlidar = package_available('ldlidar')
    has_joint_state_publisher = package_available('joint_state_publisher')
    has_usb_cam = package_available('usb_cam')
    has_image_proc = package_available('image_proc')
    
    # Configuration paths
    mqtt_config_path = os.path.join(mqtt_bridge_dir, 'config', 'params.yaml')
    
    # 2. Declare Arguments
    pub_odom_tf_arg = DeclareLaunchArgument(
        'pub_odom_tf', 
        default_value='true',
        description='Whether to publish the tf from the original odom'
    )
    
    robot_id_arg = DeclareLaunchArgument(
        'robot_id',
        default_value='robot_ugv_beast_v1',
        description='Unique ID for the Cyberwave cloud'
    )

    use_lidar_arg = DeclareLaunchArgument(
        'use_lidar',
        default_value='false',
        description='Whether to start the LiDAR driver'
    )
    
    camera_namespace_arg = DeclareLaunchArgument(
        name='camera_namespace', default_value='',
        description='Namespace for camera components'
    )
    
    camera_container_arg = DeclareLaunchArgument(
        name='camera_container', default_value='',
        description='Existing container to load camera processing nodes into'
    )

    debug_logs_arg = DeclareLaunchArgument(
        'debug_logs',
        default_value='false',
        description='Enable debug logging for MQTT bridge (shows aiortc, aioice, etc. logs)'
    )

    use_camera_arg = DeclareLaunchArgument(
        'use_camera',
        default_value='true' if has_usb_cam else 'false',
        description='Whether to start the USB camera node (requires usb_cam package)'
    )
    
    use_joint_state_pub_arg = DeclareLaunchArgument(
        'use_joint_state_publisher',
        default_value='true' if has_joint_state_publisher else 'false',
        description='Whether to start the joint_state_publisher (requires joint_state_publisher package)'
    )

    # 3. Core Hardware Node (Integrated Driver)
    # Handles Serial communication for both Telemetry and Commands
    bringup_node = Node(
        package='ugv_bringup',
        executable='ugv_integrated_driver',
        name='ugv_bringup',
        output='screen',
        remappings=[
            ('cmd_vel', '/cmd_vel'),
            ('ugv/pt_ctrl', '/ugv/pt_ctrl'),
            ('ugv/led_ctrl', '/ugv/led_ctrl'),
            ('voltage', '/voltage'),
            ('imu/data_raw', '/imu/data_raw'),
            ('imu/mag', '/imu/mag'),
            ('odom/odom_raw', '/odom/odom_raw'),
        ]
    )

    # 4. Lidar Driver (optional — only if ldlidar package is installed)
    laser_launch = None
    if has_ldlidar:
        ldlidar_dir = get_package_share_directory('ldlidar')
        laser_launch = IncludeLaunchDescription(
            PythonLaunchDescriptionSource(
                os.path.join(ldlidar_dir, 'launch', 'ldlidar.launch.py')
            ),
            condition=IfCondition(LaunchConfiguration('use_lidar'))
        )

    # 5. Robot Description & Transforms
    # Publishes the 3D model and static transforms
    set_ugv_model = SetEnvironmentVariable('UGV_MODEL', 'ugv_beast')

    urdf_model_path = os.path.join(ugv_description_dir, 'urdf', 'ugv_beast.urdf')
    with open(urdf_model_path, 'r') as f:
        robot_description_content = f.read()

    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        namespace='ugv',
        parameters=[{'robot_description': robot_description_content}]
    )

    joint_state_publisher_node = Node(
        package='joint_state_publisher',
        executable='joint_state_publisher',
        namespace='ugv',
        name='joint_state_publisher',
        condition=IfCondition(LaunchConfiguration('use_joint_state_publisher')),
        parameters=[{
            'robot_description': robot_description_content,
            'publish_default_positions': True,
        }]
    )

    # 6. Odometry Calculator
    # Computes raw odometry from wheel encoders
    base_node = Node(
        package='ugv_base_node',
        executable='base_node',
        name='base_node',
        parameters=[{'pub_odom_tf': LaunchConfiguration('pub_odom_tf')}],
        remappings=[
            ('imu/data', '/imu/data'),
            ('odom/odom_raw', '/odom/odom_raw'),
            ('odom', '/odom')
        ]
    )

    # 7. Cloud Connectivity (MQTT Bridge)
    mqtt_bridge_node = Node(
        package='mqtt_bridge',
        executable='mqtt_bridge_node',
        name='mqtt_bridge_node',
        parameters=[
            mqtt_config_path, 
            {
                'robot_id': LaunchConfiguration('robot_id'),
                'debug_logs': LaunchConfiguration('debug_logs')
            }
        ],
        output='screen'
    )

    # 8. Video Streaming (Camera)
    # Load ugv_vision defaults and allow overrides from mqtt_bridge/config/params.yaml
    camera_param_file = os.path.join(ugv_vision_dir, 'config', 'params.yaml')
    camera_overrides = {}
    try:
        mqtt_params_file = os.path.join(mqtt_bridge_dir, 'config', 'params.yaml')
        with open(mqtt_params_file, 'r') as f:
            mqtt_params = yaml.safe_load(f) or {}
        camera_overrides = (
            mqtt_params.get('/mqtt_bridge_node', {})
            .get('ros__parameters', {})
            .get('camera', {})
        )
    except Exception:
        camera_overrides = {}

    camera_node = Node(
        package='usb_cam',
        executable='usb_cam_node_exe',
        name='usb_cam',
        condition=IfCondition(LaunchConfiguration('use_camera')),
        parameters=[camera_param_file, camera_overrides],
        namespace=LaunchConfiguration('camera_namespace'),
        output='screen',
        respawn=True,
        respawn_delay=2.0
    )

    # Image processing nodes (only if image_proc is available)
    image_processing_container = None
    load_composable_nodes = None
    
    if has_image_proc:
        camera_composable_nodes = [
            ComposableNode(
                package='image_proc',
                plugin='image_proc::RectifyNode',
                name='rectify_color_node',
                namespace=LaunchConfiguration('camera_namespace'),
                remappings=[
                    ('image', 'image_raw'),
                    ('image_rect', 'image_rect')
                ],
            )
        ]

        image_processing_container = ComposableNodeContainer(
            condition=IfCondition(PythonExpression([
                "'", LaunchConfiguration('camera_container'), "' == '' and '",
                LaunchConfiguration('use_camera'), "' == 'true'"
            ])),
            name='image_proc_container',
            namespace=LaunchConfiguration('camera_namespace'),
            package='rclcpp_components',
            executable='component_container',
            composable_node_descriptions=camera_composable_nodes,
            output='screen'
        )

        load_composable_nodes = LoadComposableNodes(
            condition=IfCondition(PythonExpression([
                "'", LaunchConfiguration('camera_container'), "' != '' and '",
                LaunchConfiguration('use_camera'), "' == 'true'"
            ])),
            composable_node_descriptions=camera_composable_nodes,
            target_container=LaunchConfiguration('camera_container'),
        )

    # Build the launch description with all nodes
    ld = LaunchDescription([
        set_ugv_model,
        pub_odom_tf_arg,
        robot_id_arg,
        use_lidar_arg,
        camera_namespace_arg,
        camera_container_arg,
        debug_logs_arg,
        use_camera_arg,
        use_joint_state_pub_arg,
        bringup_node,
        robot_state_publisher_node,
        joint_state_publisher_node,
        base_node,
        mqtt_bridge_node,
        camera_node,
    ])
    
    if laser_launch is not None:
        ld.add_action(laser_launch)
    
    # Add image processing nodes only if available
    if image_processing_container is not None:
        ld.add_action(image_processing_container)
    if load_composable_nodes is not None:
        ld.add_action(load_composable_nodes)
    
    return ld
