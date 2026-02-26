"""
Command Handler Framework for MQTT Bridge Command Router

This module provides a scalable command routing system that maps MQTT commands
to ROS topics without using if-else chains. New commands can be added by:
1. Creating a handler class (for complex logic)
2. Using @register_command decorator
3. Or adding to YAML config (for simple mappings)

Design Pattern: Command Pattern + Registry Pattern
"""

import json
import base64
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, Callable
import rclpy
from rclpy.node import Node
from rclpy.publisher import Publisher

# Import common ROS message types
from geometry_msgs.msg import Twist
from std_msgs.msg import Bool, Float32MultiArray, String
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectory, JointTrajectoryPoint

# Import OpenCV for image encoding
try:
    import cv2
    import numpy as np
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False


class CommandHandler(ABC):
    """
    Abstract base class for command handlers.
    
    Each command type should implement this interface.
    Handlers are responsible for:
    1. Validating command data
    2. Converting MQTT data to ROS messages
    3. Publishing to appropriate ROS topics
    """
    
    def __init__(self, node: Node):
        """
        Initialize handler with ROS node.
        
        Args:
            node: ROS2 node for creating publishers and logging
        """
        self.node = node
        self.logger = node.get_logger()
        self._publishers: Dict[str, Publisher] = {}
        self._mqtt_adapter: Any = None
        self._command_topic: Optional[str] = None
        self._setup_publishers()
    
    def set_mqtt_context(self, adapter: Any, command_topic: str):
        """Set the MQTT adapter and topic for sending responses."""
        self._mqtt_adapter = adapter
        self._command_topic = command_topic

    def publish_response(self, response_data: Dict[str, Any]) -> bool:
        """
        Publish a response back to the same MQTT command topic.
        
        Args:
            response_data: Data to send back to the frontend
            
        Returns:
            True if published, False otherwise
        """
        if not self._mqtt_adapter or not self._command_topic:
            self.logger.warning("Cannot publish response: MQTT context not set")
            return False
            
        try:
            # Wrap response with metadata if not already present
            payload = {
                "command": self.get_command_name(),
                "type": "response",
                "source_type": "edge",  # Explicitly mark as edge to avoid bridge loopback logs
                "data": response_data
            }
            # Serialize payload to JSON string before publishing
            json_payload = json.dumps(payload)
            self._mqtt_adapter.publish(self._command_topic, json_payload)
            return True
        except Exception as e:
            self.logger.error(f"Failed to publish response: {e}")
            return False
    
    def publish_simple_response(self, response_data: Dict[str, Any]) -> bool:
        """
        Publish a simple response (without command/type wrapper) for video commands.
        This matches the format expected by the frontend for start_video/stop_video.
        
        Args:
            response_data: Data to send back (e.g., {"status": "ok", "type": "video_started"})
            
        Returns:
            True if published, False otherwise
        """
        if not self._mqtt_adapter or not self._command_topic:
            self.logger.warning("Cannot publish simple response: MQTT context not set")
            return False
            
        try:
            # Send response directly without wrapping (for video commands compatibility)
            json_payload = json.dumps(response_data)
            self._mqtt_adapter.publish(self._command_topic, json_payload)
            return True
        except Exception as e:
            self.logger.error(f"Failed to publish simple response: {e}")
            return False

    @abstractmethod
    def _setup_publishers(self) -> None:
        """Create ROS publishers needed for this command."""
        pass
    
    @abstractmethod
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle the command with given data.
        
        Args:
            data: Command data dictionary from MQTT message
            
        Returns:
            True if command was handled successfully, False otherwise
        """
        pass
    
    @abstractmethod
    def get_command_name(self) -> str:
        """Return the command name this handler processes."""
        pass
    
    def validate_data(self, data: Dict[str, Any], required_fields: list) -> bool:
        """
        Validate that required fields are present in data.
        
        Args:
            data: Data dictionary to validate
            required_fields: List of required field names
            
        Returns:
            True if all fields present, False otherwise
        """
        missing = [f for f in required_fields if f not in data]
        if missing:
            self.logger.warning(
                f"Command '{self.get_command_name()}' missing fields: {missing}"
            )
            return False
        return True


class GenericActuationHandler(CommandHandler):
    """
    GENERIC handler for actuation-based commands from frontend.
    
    This handler maps simple actuation strings (e.g., "move_forward", "turn_left")
    to appropriate ROS messages, enabling universal command-based control for
    ANY robot using "control_mode": "command".
    
    Supported actuations:
    - Locomotion: move_forward, move_backward, turn_left, turn_right, stop
    - Camera: camera_up, camera_down, camera_left, camera_right
    - Lights: chassis_light_toggle, camera_light_toggle, led_toggle
    - Utilities: take_photo, battery_check
    - Robot-specific: sit_down, stand_up, obstacle_avoidance_toggle
    
    Configuration:
    - Linear speed: Default 0.5 m/s (can be configured via ROS params)
    - Angular speed: Default 0.8 rad/s (can be configured via ROS params)
    """
    
    def __init__(self, node: Node):
        # Velocity configurations based on Waveshare UGV Beast specifications
        # 
        # Research findings:
        # - UGV Beast maximum speed: 0.35 m/s (official spec)
        # - Safe teleoperation speed: 0.3 m/s (85% of max for smooth control)
        # - Angular velocity: ~1.0 rad/s (based on differential drive kinematics)
        # 
        # Sources:
        # - https://www.waveshare.com/wiki/UGV_Beast_PI_ROS2
        # - Differential drive formula: ω_max = (2 × v_wheel) / wheel_separation
        # - With wheel speed ≈0.35 m/s and typical separation ~0.4m: ω ≈ 1.0-1.25 rad/s
        self._linear_speed = 0.3   # m/s (safe teleoperation speed)
        self._angular_speed = 1.0  # rad/s (safe turning speed)
        self._camera_step = 0.1    # radians per key press
        
        # Track light states for toggles
        self._chassis_light_on = False
        self._camera_light_on = False
        self._led_on = False
        
        # Camera servo current position
        self._camera_pan = 0.0
        self._camera_tilt = 0.0
        
        super().__init__(node)
        self.logger.info(
            f"GenericActuationHandler initialized: "
            f"linear_speed={self._linear_speed} m/s, "
            f"angular_speed={self._angular_speed} rad/s"
        )
    
    def get_command_name(self) -> str:
        return "actuation"
    
    def _setup_publishers(self) -> None:
        """Create publishers for all possible actuation types."""
        # Movement
        self._publishers['cmd_vel'] = self.node.create_publisher(
            Twist, '/cmd_vel', 10
        )
        
        # Lights (UGV Beast specific, but safe to create)
        self._publishers['led_ctrl'] = self.node.create_publisher(
            Float32MultiArray, '/ugv/led_ctrl', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle generic actuation command.
        
        Expected data formats (from frontend):
        
        1. Simple commands (keyboard controller):
        {
            "command": "move_forward",
            "timestamp": 1706547890.123,
            "source_type": "tele"
        }
        
        2. Complex commands (video streaming):
        {
            "command": "start_video",
            "data": {"camera": "default", "recording": true},
            "timestamp": 1706547890.123,
            "source_type": "tele"
        }
        """
        try:
            self.logger.info(f"[DEBUG] GenericActuationHandler.handle() called with data: {data}")
            
            # Extract the actuation command
            actuation = data.get('command')
            if not actuation:
                self.logger.warning("Actuation handler requires 'command' field")
                return False
            
            self.logger.info(f"Processing actuation: {actuation}")
            
            # Extract additional data if present (for video commands, etc.)
            command_data = data.get('data', {})
            
            # Map actuation to ROS command
            result = self._process_actuation(actuation, command_data)
            self.logger.info(f"[DEBUG] _process_actuation returned: {result}")
            return result
            
        except Exception as e:
            self.logger.error(f"Failed to handle actuation: {e}")
            import traceback
            self.logger.error(traceback.format_exc())
            return False
    
    def _process_actuation(self, actuation: str, data: Dict[str, Any] = None) -> bool:
        """
        Map actuation string to appropriate ROS message.
        
        This is the GENERIC mapping function that converts simple actuation
        commands to ROS messages.
        """
        # ============= LOCOMOTION ACTUATIONS =============
        if actuation == "move_forward":
            return self._send_twist(self._linear_speed, 0.0)
        
        elif actuation == "move_backward":
            return self._send_twist(-self._linear_speed, 0.0)
        
        elif actuation == "turn_left":
            return self._send_twist(0.0, self._angular_speed)
        
        elif actuation == "turn_right":
            return self._send_twist(0.0, -self._angular_speed)
        
        elif actuation == "stop":
            return self._send_twist(0.0, 0.0)
        
        # ============= CAMERA SERVO ACTUATIONS =============
        elif actuation == "camera_up":
            return self._send_camera_servo(tilt_delta=self._camera_step)
        
        elif actuation == "camera_down":
            return self._send_camera_servo(tilt_delta=-self._camera_step)
        
        elif actuation == "camera_left":
            return self._send_camera_servo(pan_delta=-self._camera_step)
        
        elif actuation == "camera_right":
            return self._send_camera_servo(pan_delta=self._camera_step)
        
        elif actuation == "camera_default":
            # Reset camera to default position (0.0, 0.0)
            return self._send_camera_servo_reset()
        
        # ============= LIGHT ACTUATIONS =============
        elif actuation == "chassis_light_toggle":
            self._chassis_light_on = not self._chassis_light_on
            return self._send_led_ctrl(chassis=255 if self._chassis_light_on else 0)
        
        elif actuation == "camera_light_toggle":
            self._camera_light_on = not self._camera_light_on
            return self._send_led_ctrl(camera=255 if self._camera_light_on else 0)
        
        elif actuation == "led_toggle":
            self._led_on = not self._led_on
            value = 255 if self._led_on else 0
            return self._send_led_ctrl(chassis=value, camera=value)
        
        # ============= UTILITY ACTUATIONS =============
        elif actuation == "take_photo":
            # Delegate to TakePhotoHandler via command registry
            if hasattr(self.node, '_command_registry'):
                return self.node._command_registry.handle_command("take_photo", {})
            self.logger.warning("take_photo: command registry not available")
            return False
        
        elif actuation == "battery_check":
            # Delegate to BatteryCheckHandler via command registry
            if hasattr(self.node, '_command_registry'):
                return self.node._command_registry.handle_command("battery_check", {})
            self.logger.warning("battery_check: command registry not available")
            return False
        
        # ============= VIDEO STREAM ACTUATIONS =============
        elif actuation == "start_video":
            # Start camera WebRTC streaming
            try:
                if hasattr(self.node, 'start_camera_stream'):
                    # Extract recording preference from data if provided
                    recording = True  # Default
                    if data and isinstance(data, dict):
                        recording = data.get('recording', True)
                    
                    self.logger.info(f"Starting video stream (recording={recording})")
                    self.node.start_camera_stream(recording=recording)
                    
                    # Send upstream response in simple format (FE expects this)
                    self.publish_simple_response({"status": "ok", "type": "video_started"})
                    return True
                else:
                    self.logger.error("start_video: node.start_camera_stream() not available")
                    self.publish_simple_response({"status": "error", "message": "Video streaming not supported"})
                    return False
            except Exception as e:
                self.logger.error(f"Failed to start video stream: {e}")
                self.publish_simple_response({"status": "error", "message": str(e)})
                return False
        
        elif actuation == "stop_video":
            # Stop camera WebRTC streaming
            try:
                if hasattr(self.node, 'stop_camera_stream'):
                    self.logger.info("Stopping video stream")
                    self.node.stop_camera_stream()
                    
                    # Send upstream response in simple format (FE expects this)
                    self.publish_simple_response({"status": "ok", "type": "video_stopped"})
                    return True
                else:
                    self.logger.error("stop_video: node.stop_camera_stream() not available")
                    self.publish_simple_response({"status": "error", "message": "Video streaming not supported"})
                    return False
            except Exception as e:
                self.logger.error(f"Failed to stop video stream: {e}")
                self.publish_simple_response({"status": "error", "message": str(e)})
                return False
        
        # ============= ROBOT-SPECIFIC ACTUATIONS =============
        # These are placeholders - implement based on specific robot capabilities
        elif actuation == "sit_down":
            self.logger.info("sit_down actuation (no ROS topic mapped yet)")
            self.publish_response({"status": "not_implemented", "actuation": actuation})
            return True
        
        elif actuation == "stand_up":
            self.logger.info("stand_up actuation (no ROS topic mapped yet)")
            self.publish_response({"status": "not_implemented", "actuation": actuation})
            return True
        
        elif actuation == "obstacle_avoidance_toggle":
            self.logger.info("obstacle_avoidance_toggle actuation (no ROS topic mapped yet)")
            self.publish_response({"status": "not_implemented", "actuation": actuation})
            return True
        
        # ============= UNKNOWN ACTUATION =============
        else:
            self.logger.warning(
                f"Unknown actuation: {actuation}. "
                f"Add mapping in GenericActuationHandler._process_actuation()"
            )
            self.publish_response({
                "status": "error",
                "message": f"Unknown actuation: {actuation}"
            })
            return False
    
    def _send_twist(self, linear_x: float, angular_z: float) -> bool:
        """Send a Twist message for locomotion."""
        try:
            msg = Twist()
            msg.linear.x = float(linear_x)
            msg.linear.y = 0.0
            msg.linear.z = 0.0
            msg.angular.x = 0.0
            msg.angular.y = 0.0
            msg.angular.z = float(angular_z)
            
            self._publishers['cmd_vel'].publish(msg)
            self.logger.debug(f"Published Twist: linear.x={linear_x}, angular.z={angular_z}")
            
            # Send confirmation
            self.publish_response({
                "status": "success",
                "linear_x": linear_x,
                "angular_z": angular_z
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to send Twist: {e}")
            return False
    
    def _send_camera_servo(self, pan_delta: float = 0.0, tilt_delta: float = 0.0) -> bool:
        """Send camera servo command via camera_servo handler."""
        try:
            # Delegate to CameraServoHandler via command registry
            if hasattr(self.node, '_command_registry'):
                servo_data = {}
                if pan_delta != 0.0:
                    servo_data['pan_delta'] = pan_delta
                if tilt_delta != 0.0:
                    servo_data['tilt_delta'] = tilt_delta
                
                return self.node._command_registry.handle_command("camera_servo", servo_data)
            
            self.logger.warning("camera_servo: command registry not available")
            return False
            
        except Exception as e:
            self.logger.error(f"Failed to send camera servo: {e}")
            return False
    
    def _send_camera_servo_reset(self) -> bool:
        """Reset camera servo to default position (0.0, 0.0)."""
        try:
            self.logger.info("[DEBUG] _send_camera_servo_reset() called")
            
            # Delegate to CameraServoHandler via command registry with absolute positions
            if hasattr(self.node, '_command_registry'):
                servo_data = {
                    'pan': 0.0,
                    'tilt': 0.0
                }
                self.logger.info(f"[DEBUG] Calling command registry with camera_servo command: {servo_data}")
                result = self.node._command_registry.handle_command("camera_servo", servo_data)
                self.logger.info(f"[DEBUG] camera_servo handler returned: {result}")
                return result
            
            self.logger.warning("camera_servo: command registry not available")
            return False
            
        except Exception as e:
            self.logger.error(f"Failed to reset camera servo: {e}")
            import traceback
            self.logger.error(traceback.format_exc())
            return False
    
    def _send_led_ctrl(self, chassis: Optional[float] = None, camera: Optional[float] = None) -> bool:
        """Send LED control command."""
        try:
            # Delegate to LedCtrlHandler via command registry
            if hasattr(self.node, '_command_registry'):
                led_data = {}
                if chassis is not None:
                    led_data['chassis_light'] = chassis
                if camera is not None:
                    led_data['camera_light'] = camera
                
                return self.node._command_registry.handle_command("led_ctrl", led_data)
            
            self.logger.warning("led_ctrl: command registry not available")
            return False
            
        except Exception as e:
            self.logger.error(f"Failed to send LED control: {e}")
            return False


class CmdVelHandler(CommandHandler):
    """Handler for velocity commands (Twist messages)."""
    
    def get_command_name(self) -> str:
        return "cmd_vel"
    
    def _setup_publishers(self) -> None:
        self._publishers['cmd_vel'] = self.node.create_publisher(
            Twist, '/cmd_vel', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle velocity command.
        
        Expected data format:
        {
            "linear": {"x": 0.5, "y": 0.0, "z": 0.0},
            "angular": {"x": 0.0, "y": 0.0, "z": 0.3}
        }
        """
        try:
            msg = Twist()
            
            # Extract linear velocity
            linear = data.get('linear', {})
            msg.linear.x = float(linear.get('x', 0.0))
            msg.linear.y = float(linear.get('y', 0.0))
            msg.linear.z = float(linear.get('z', 0.0))
            
            # Extract angular velocity
            angular = data.get('angular', {})
            msg.angular.x = float(angular.get('x', 0.0))
            msg.angular.y = float(angular.get('y', 0.0))
            msg.angular.z = float(angular.get('z', 0.0))
            
            self._publishers['cmd_vel'].publish(msg)
            
            # Send confirmation response
            self.publish_response({
                "status": "success",
                "linear": {"x": msg.linear.x, "y": msg.linear.y, "z": msg.linear.z},
                "angular": {"x": msg.angular.x, "y": msg.angular.y, "z": msg.angular.z}
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle cmd_vel: {e}")
            return False


class LedCtrlHandler(CommandHandler):
    """
    Handler for UGV Beast LED/headlight control commands.
    
    Controls:
    - IO4: Chassis headlight (near OKA camera)
    - IO5: Camera pan-tilt headlight (USB camera)
    
    Values: 0 = off, 255 = on
    """
    
    def __init__(self, node: Node):
        super().__init__(node)
        # Track current LED states
        self._chassis_light_value = 0.0  # IO4
        self._camera_light_value = 0.0   # IO5
    
    def get_command_name(self) -> str:
        return "led_ctrl"
    
    def _setup_publishers(self) -> None:
        self._publishers['led_ctrl'] = self.node.create_publisher(
            Float32MultiArray, '/ugv/led_ctrl', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle LED/headlight control command.
        
        Supported formats:
        
        1. ROS-like format:
           {"data": [255, 255]}
        
        2. Array helper format:
           {"leds": [255, 255]}
           - leds[0] = IO4 (chassis headlight)
           - leds[1] = IO5 (camera headlight)
        
        3. Named format:
           {"io4": 255, "io5": 0}
           {"chassis_light": 255, "camera_light": 0}
        
        4. Convenience format:
           {"all": 255}  // Turn all lights on/off
        
        Values: 0 = off, 255 = on (or 0-255 for dimming if supported)
        """
        try:
            msg = Float32MultiArray()
            
            # Format 1 & 2: Array formats
            if 'data' in data:
                msg.data = [float(v) for v in data['data']]
            elif 'leds' in data:
                msg.data = [float(v) for v in data['leds']]
            
            # Format 3: Named IO format
            elif 'io4' in data or 'io5' in data:
                io4 = float(data.get('io4', 0))
                io5 = float(data.get('io5', 0))
                msg.data = [io4, io5]
            
            # Format 4: Named descriptive format
            elif 'chassis_light' in data or 'camera_light' in data:
                chassis = float(data.get('chassis_light', 0))
                camera = float(data.get('camera_light', 0))
                msg.data = [chassis, camera]
            
            # Format 5: Convenience - all lights same value
            elif 'all' in data:
                value = float(data['all'])
                msg.data = [value, value]
            
            else:
                self.logger.warning(
                    "led_ctrl requires one of: 'data', 'leds', 'io4/io5', "
                    "'chassis_light/camera_light', or 'all'"
                )
                return False
            
            # Ensure we have exactly 2 elements as expected by UGV Beast driver
            if len(msg.data) < 2:
                msg.data.extend([0.0] * (2 - len(msg.data)))
            
            # Track current LED states
            self._chassis_light_value = msg.data[0]
            self._camera_light_value = msg.data[1]
            
            self._publishers['led_ctrl'].publish(msg)
            
            # Publish status to MQTT for UI updates
            self._publish_status_to_mqtt()
            
            # Send response back to MQTT
            self.publish_response({
                "status": "success",
                "io4": msg.data[0],
                "io5": msg.data[1],
                "chassis_light": "on" if msg.data[0] > 0 else "off",
                "camera_light": "on" if msg.data[1] > 0 else "off"
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle led_ctrl: {e}")
            return False
    
    def _publish_status_to_mqtt(self) -> None:
        """Publish LED status to MQTT for UI updates."""
        try:
            # Get twin UUID and prefix
            twin_uuid = None
            if hasattr(self.node, '_mapping') and self.node._mapping:
                twin_uuid = getattr(self.node._mapping, 'twin_uuid', None)
            
            if not twin_uuid or not self._mqtt_adapter:
                return
            
            prefix = getattr(self.node, 'ros_prefix', '')
            topic = f"{prefix}cyberwave/twin/{twin_uuid}/status/lights"
            
            payload = {
                "source_type": "edge",
                "timestamp": self.node.get_clock().now().nanoseconds / 1e9,
                "chassis_light": "on" if self._chassis_light_value > 0 else "off",
                "camera_light": "on" if self._camera_light_value > 0 else "off",
                "chassis_light_value": int(self._chassis_light_value),
                "camera_light_value": int(self._camera_light_value)
            }
            
            self._mqtt_adapter.publish(topic, payload)
            self.logger.debug(f"Published LED status: chassis={'on' if self._chassis_light_value > 0 else 'off'}, camera={'on' if self._camera_light_value > 0 else 'off'}")
            
        except Exception as e:
            self.logger.warning(f"Failed to publish LED status to MQTT: {e}")


class EmergencyStopHandler(CommandHandler):
    """Handler for emergency stop commands."""
    
    def get_command_name(self) -> str:
        return "estop"
    
    def _setup_publishers(self) -> None:
        self._publishers['estop'] = self.node.create_publisher(
            Bool, '/emergency_stop', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle emergency stop command.
        
        Expected data format:
        {
            "activate": true
        }
        """
        try:
            if not self.validate_data(data, ['activate']):
                return False
            
            msg = Bool()
            msg.data = bool(data['activate'])
            
            self._publishers['estop'].publish(msg)
            self.logger.warn(f"Emergency stop {'ACTIVATED' if msg.data else 'DEACTIVATED'}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle estop: {e}")
            return False


class OledCtrlHandler(CommandHandler):
    """Handler for UGV Beast OLED display commands."""
    
    def get_command_name(self) -> str:
        return "oled_ctrl"
    
    def _setup_publishers(self) -> None:
        self._publishers['oled_ctrl'] = self.node.create_publisher(
            String, '/ugv/oled_ctrl', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle OLED control command.
        
        Expected data format:
        {"text": "Hello"} or {"data": "Hello"} or just a string "Hello"
        """
        try:
            msg = String()
            if isinstance(data, str):
                msg.data = data
            elif 'text' in data:
                msg.data = str(data['text'])
            elif 'data' in data:
                msg.data = str(data['data'])
            else:
                self.logger.warning("oled_ctrl requires 'text' or 'data' field")
                return False
            
            self._publishers['oled_ctrl'].publish(msg)
            
            # Send confirmation response
            self.publish_response({"status": "displayed", "text": msg.data})
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle oled_ctrl: {e}")
            return False


class JointTrajectoryHandler(CommandHandler):
    """Handler for sending joint trajectories (individual wheel/joint control)."""
    
    def get_command_name(self) -> str:
        return "trajectory"
    
    def _setup_publishers(self) -> None:
        self._publishers['trajectory'] = self.node.create_publisher(
            JointTrajectory, '/scaled_joint_trajectory_controller/joint_trajectory', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle trajectory command.
        
        Expected data format:
        {
            "joint_names": ["left_up_wheel_link_joint", ...],
            "points": [{
                "positions": [0.0, ...],
                "velocities": [1.0, ...],
                "time_from_start": {"sec": 1, "nanosec": 0}
            }]
        }
        """
        try:
            if not self.validate_data(data, ['joint_names', 'points']):
                return False
            
            msg = JointTrajectory()
            msg.header.stamp = self.node.get_clock().now().to_msg()
            msg.joint_names = data['joint_names']
            
            for pt_data in data['points']:
                point = JointTrajectoryPoint()
                point.positions = [float(v) for v in pt_data.get('positions', [])]
                point.velocities = [float(v) for v in pt_data.get('velocities', [])]
                
                tfs = pt_data.get('time_from_start', {})
                point.time_from_start.sec = int(tfs.get('sec', 0))
                point.time_from_start.nanosec = int(tfs.get('nanosec', 0))
                
                msg.points.append(point)
            
            self._publishers['trajectory'].publish(msg)
            
            self.publish_response({
                "status": "success",
                "joints": msg.joint_names,
                "points_count": len(msg.points)
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle trajectory: {e}")
            return False


class GripperHandler(CommandHandler):
    """Handler for gripper control commands."""
    
    def get_command_name(self) -> str:
        return "gripper"
    
    def _setup_publishers(self) -> None:
        # Using String for simplicity - can be upgraded to service call
        self._publishers['gripper'] = self.node.create_publisher(
            String, '/gripper/command', 10
        )
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle gripper command.
        
        Expected data format:
        {
            "action": "grip"  // or "release", "reset"
        }
        """
        try:
            if not self.validate_data(data, ['action']):
                return False
            
            action = data['action']
            if action not in ['grip', 'release', 'reset']:
                self.logger.warning(f"Invalid gripper action: {action}")
                return False
            
            msg = String()
            msg.data = action
            
            self._publishers['gripper'].publish(msg)
            
            # Send confirmation response
            self.publish_response({"status": "executed", "action": action})
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle gripper: {e}")
            return False


class CameraServoHandler(CommandHandler):
    """
    Handler for UGV Beast pan-tilt camera servo control with smooth interpolation.
    
    Controls the pan-tilt mechanism via joint trajectory commands.
    Pan joint: pt_base_link_to_pt_link1 (horizontal rotation)
    Tilt joint: pt_link1_to_pt_link2 (vertical movement)
    """
    
    def __init__(self, node: Node):
        super().__init__(node)
        # Track current servo positions
        self._pan_position = 0.0   # radians
        self._tilt_position = 0.0  # radians
        
        # Servo limits (in radians)
        self._pan_min = -3.14159   # -180 degrees
        self._pan_max = 3.14159    # +180 degrees
        self._tilt_min = -0.785    # -45 degrees
        self._tilt_max = 1.57      # +90 degrees
        
        # Interpolation settings - optimized for fast & smooth
        self._interpolation_steps = 4  # Number of intermediate steps
        self._interpolation_interval = 0.02  # seconds between steps (20ms)
        self._interpolation_timer = None
        self._target_pan = 0.0
        self._target_tilt = 0.0
        self._current_step = 0
        
        self.logger.info("CameraServoHandler initialized with smooth interpolation")
    
    def get_command_name(self) -> str:
        return "camera_servo"
    
    def _setup_publishers(self) -> None:
        # UGV Beast uses /ugv/joint_states for servo control, not trajectory controller
        self._publishers['joint_states'] = self.node.create_publisher(
            JointState, '/ugv/joint_states', 10
        )
    
    def _interpolate_step(self) -> None:
        """Execute one step of the interpolation."""
        if self._current_step >= self._interpolation_steps:
            # Interpolation complete
            if self._interpolation_timer is not None:
                self._interpolation_timer.cancel()
                self._interpolation_timer = None
            return
        
        # Calculate interpolation progress (0.0 to 1.0)
        progress = self._current_step / self._interpolation_steps
        
        # Ease-in-out for smooth acceleration/deceleration (smoothstep function)
        progress = progress * progress * (3.0 - 2.0 * progress)
        
        # Calculate intermediate position
        start_pan = self._pan_position
        start_tilt = self._tilt_position
        
        self._pan_position = start_pan + (self._target_pan - start_pan) * progress
        self._tilt_position = start_tilt + (self._target_tilt - start_tilt) * progress
        
        # Publish intermediate position
        self._publish_position()
        
        # Move to next step
        self._current_step += 1
    
    def _publish_position(self) -> None:
        """Publish current servo position to ROS topic."""
        msg = JointState()
        msg.header.stamp = self.node.get_clock().now().to_msg()
        msg.header.frame_id = 'tele'  # CRITICAL: Must be 'tele' for ugv_integrated_driver to accept
        msg.name = ['pt_base_link_to_pt_link1', 'pt_link1_to_pt_link2']
        msg.position = [self._pan_position, self._tilt_position]
        msg.velocity = []
        msg.effort = []
        
        self._publishers['joint_states'].publish(msg)
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle camera servo command with smooth interpolation.
        
        Expected data format:
        {
            "pan_delta": 0.1,    # Optional: change in pan (radians)
            "tilt_delta": -0.1,  # Optional: change in tilt (radians)
            "pan": 0.5,          # Optional: absolute pan position (radians)
            "tilt": 0.3          # Optional: absolute tilt position (radians)
        }
        """
        try:
            self.logger.info(f"[DEBUG] CameraServoHandler.handle() called with data: {data}")
            
            # Cancel any ongoing interpolation
            if self._interpolation_timer is not None:
                self._interpolation_timer.cancel()
                self._interpolation_timer = None
            
            # Calculate target position
            pan_delta = data.get('pan_delta', 0.0)
            tilt_delta = data.get('tilt_delta', 0.0)
            
            # Check if absolute positions are provided
            if 'pan' in data:
                self._target_pan = float(data['pan'])
                self.logger.info(f"[DEBUG] Setting absolute pan position: {self._target_pan}")
            else:
                self._target_pan = self._pan_position + float(pan_delta)
                self.logger.info(f"[DEBUG] Setting relative pan position: {self._target_pan} (delta: {pan_delta})")
            
            if 'tilt' in data:
                self._target_tilt = float(data['tilt'])
                self.logger.info(f"[DEBUG] Setting absolute tilt position: {self._target_tilt}")
            else:
                self._target_tilt = self._tilt_position + float(tilt_delta)
                self.logger.info(f"[DEBUG] Setting relative tilt position: {self._target_tilt} (delta: {tilt_delta})")
            
            # Clamp target to limits
            self._target_pan = max(self._pan_min, min(self._pan_max, self._target_pan))
            self._target_tilt = max(self._tilt_min, min(self._tilt_max, self._target_tilt))
            
            # Start interpolation
            self._current_step = 1  # Start from step 1 (0 would be current position)
            
            # Create timer for interpolation steps
            self._interpolation_timer = self.node.create_timer(
                self._interpolation_interval,
                self._interpolate_step
            )
            
            self.logger.debug(
                f"Camera servo: target pan={self._target_pan:.3f}, tilt={self._target_tilt:.3f}"
            )
            
            # Publish status to MQTT for UI updates
            self._publish_status_to_mqtt()
            
            # Send confirmation response with target position
            self.publish_response({
                "status": "success",
                "pan": self._target_pan,
                "tilt": self._target_tilt
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle camera servo: {e}")
            return False
    
    def _publish_status_to_mqtt(self) -> None:
        """Publish camera servo status to MQTT for UI updates."""
        try:
            import math
            
            # Get twin UUID and prefix
            twin_uuid = None
            if hasattr(self.node, '_mapping') and self.node._mapping:
                twin_uuid = getattr(self.node._mapping, 'twin_uuid', None)
            
            if not twin_uuid or not self._mqtt_adapter:
                return
            
            prefix = getattr(self.node, 'ros_prefix', '')
            topic = f"{prefix}cyberwave/twin/{twin_uuid}/status/camera_servo"
            
            # Convert radians to degrees for display
            pan_deg = math.degrees(self._target_pan)
            tilt_deg = math.degrees(self._target_tilt)
            
            payload = {
                "source_type": "edge",
                "timestamp": self.node.get_clock().now().nanoseconds / 1e9,
                "pan_degrees": round(pan_deg, 1),
                "tilt_degrees": round(tilt_deg, 1),
                "pan_radians": round(self._target_pan, 3),
                "tilt_radians": round(self._target_tilt, 3)
            }
            
            self._mqtt_adapter.publish(topic, payload)
            self.logger.debug(f"Published camera servo status: pan={pan_deg:.1f}°, tilt={tilt_deg:.1f}°")
            
        except Exception as e:
            self.logger.warning(f"Failed to publish camera servo status to MQTT: {e}")


class BatteryCheckHandler(CommandHandler):
    """Handler for explicit battery level check."""
    
    def get_command_name(self) -> str:
        return "battery_check"
    
    def _setup_publishers(self) -> None:
        pass
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """Handle battery check command."""
        try:
            # Try to get battery data from the node's cache or direct method
            battery_data = None
            if hasattr(self.node, '_last_battery_msg') and self.node._last_battery_msg:
                battery_data = self.node._last_battery_msg
            
            if battery_data:
                # Determine topic
                twin_uuid = None
                if hasattr(self.node, '_mapping') and self.node._mapping:
                    twin_uuid = getattr(self.node._mapping, 'twin_uuid', None)
                
                if twin_uuid:
                    prefix = getattr(self.node, 'ros_prefix', '')
                    topic = f"{prefix}cyberwave/twin/{twin_uuid}/status/battery"
                    
                    # Use the node's encoder to format the battery state
                    # This will include source_type: 'edge' and the standard payload
                    payload = self.node._encode_msg_for_mqtt(battery_data, type(battery_data), mqtt_topic=topic)
                    
                    if self._mqtt_adapter:
                        self._mqtt_adapter.publish(topic, payload)
                    
                # Also send confirmation response on command topic
                self.publish_response({
                    "status": "success",
                    "command": "battery_check",
                    "message": "Battery status published to telemetry topic"
                })
            else:
                self.publish_response({
                    "status": "error",
                    "command": "battery_check",
                    "message": "Battery data not available yet"
                })
            return True
        except Exception as e:
            self.logger.error(f"Failed to handle battery check: {e}")
            return False


class TakePhotoHandler(CommandHandler):
    """Handler for taking a photo/snapshot from the camera."""
    
    def get_command_name(self) -> str:
        return "take_photo"
    
    def _setup_publishers(self) -> None:
        pass
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """Handle take_photo command."""
        try:
            if not CV2_AVAILABLE:
                self.publish_response({
                    "status": "error",
                    "command": "take_photo",
                    "message": "OpenCV not available for image encoding"
                })
                return False
            
            # Try to get the latest frame from the camera streamer
            frame = None
            if hasattr(self.node, '_ros_streamer') and self.node._ros_streamer:
                if hasattr(self.node._ros_streamer, 'streamer') and self.node._ros_streamer.streamer:
                    if hasattr(self.node._ros_streamer.streamer, 'latest_frame'):
                        frame = self.node._ros_streamer.streamer.latest_frame
            
            if frame is None:
                self.publish_response({
                    "status": "error",
                    "command": "take_photo",
                    "message": "No camera frame available"
                })
                return False
            
            # Encode frame to JPEG
            success, encoded_image = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            
            if not success:
                self.publish_response({
                    "status": "error",
                    "command": "take_photo",
                    "message": "Failed to encode image"
                })
                return False
            
            # Convert to base64
            image_base64 = base64.b64encode(encoded_image.tobytes()).decode('utf-8')
            
            # Get twin UUID for topic
            twin_uuid = None
            if hasattr(self.node, '_mapping') and self.node._mapping:
                twin_uuid = getattr(self.node._mapping, 'twin_uuid', None)
            
            if twin_uuid and self._mqtt_adapter:
                prefix = getattr(self.node, 'ros_prefix', '')
                
                # Publish the captured image to a dedicated photo topic
                photo_topic = f"{prefix}cyberwave/twin/{twin_uuid}/camera/photo"
                photo_payload = {
                    "source_type": "edge",
                    "timestamp": self.node.get_clock().now().nanoseconds / 1e9,
                    "image": image_base64,
                    "format": "jpeg",
                    "width": frame.shape[1],
                    "height": frame.shape[0]
                }
                self._mqtt_adapter.publish(photo_topic, photo_payload)
                self.logger.info(f"Published photo to {photo_topic} ({len(image_base64)} bytes)")
            
            # Send success response
            self.publish_response({
                "status": "success",
                "command": "take_photo",
                "message": "Photo captured successfully",
                "image_size": len(image_base64)
            })
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle take_photo: {e}")
            self.publish_response({
                "status": "error",
                "command": "take_photo",
                "message": f"Exception: {str(e)}"
            })
            return False


class CameraCommandHandler(CommandHandler):
    """Handles frontend video streaming commands."""
    def __init__(self, node: Node, command_name: str):
        super().__init__(node)
        self._command_name = command_name

    def get_command_name(self) -> str:
        return self._command_name
        
    def _setup_publishers(self) -> None:
        pass

    def handle(self, data: Any) -> bool:
        # Commands from FE: "start_video" or "stop_video"
        if self._command_name == "start_video":
            self.node.start_camera_stream()
            self.publish_response({"status": "ok", "type": "video_started"})
        elif self._command_name == "stop_video":
            self.node.stop_camera_stream()
            self.publish_response({"status": "ok", "type": "video_stopped"})
        return True

class StatusQueryHandler(CommandHandler):
    """Handler for querying robot status (IMU, Battery, Odom)."""
    
    def get_command_name(self) -> str:
        return "get_status"
    
    def _setup_publishers(self) -> None:
        # No publishers needed, we just read from the node's state
        pass
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle status query command.
        
        Expected data format:
        {
            "target": "battery"  // or "imu", "odom", "joint_states", "all"
        }
        """
        try:
            target = data.get('target', 'all')
            
            # Map simple target names to actual ROS topics
            topic_map = {
                "battery": "/ugv/battery_status",
                "imu": "/ugv/imu",
                "odom": "/odom",
                "joint_states": "/ugv/joint_states",
                "cmd_vel": "/cmd_vel",
                "led_ctrl": "/ugv/led_ctrl",
                "oled_ctrl": "/ugv/oled_ctrl"
            }
            
            # Get the cache from the node
            cache = getattr(self.node, '_ros_state_cache', {})
            
            if target == 'all':
                response_data = {}
                for name, topic in topic_map.items():
                    msg = cache.get(topic)
                    if msg:
                        response_data[name] = self._serialize_msg(msg)
                self.publish_response({
                    "status": "success",
                    "data": response_data
                })
            elif target in topic_map:
                topic = topic_map[target]
                msg = cache.get(topic)
                if msg:
                    self.publish_response({
                        "status": "success",
                        "target": target,
                        "data": self._serialize_msg(msg)
                    })
                else:
                    self.publish_response({
                        "status": "error",
                        "message": f"No data cached for {target} ({topic})"
                    })
            else:
                self.publish_response({
                    "status": "error",
                    "message": f"Unknown status target: {target}. Available: {list(topic_map.keys())}"
                })
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to handle status query: {e}")
            return False

    def _serialize_msg(self, msg) -> Any:
        """Helper to serialize ROS message to dict."""
        try:
            # Try to use the node's encoder if available (it handles JointState and battery status specially)
            if hasattr(self.node, '_encode_msg_for_mqtt'):
                import json
                # Determine context topic if possible
                context_topic = None
                if 'battery' in str(type(msg)).lower() or 'float' in str(type(msg)).lower():
                    # For battery status, we need to pass a topic containing 'status/battery' to trigger special encoding
                    # if the type is Float32.
                    context_topic = 'cyberwave/twin/unknown/status/battery'
                
                encoded = self.node._encode_msg_for_mqtt(msg, type(msg), mqtt_topic=context_topic)
                return json.loads(encoded)
            
            # Fallback to direct conversion
            from rosidl_runtime_py.convert import message_to_ordereddict
            return message_to_ordereddict(msg)
        except Exception:
            return str(msg)


class LightsCommandHandler(CommandHandler):
    """
    Handler for 'lights' command with PWM support.
    Accepts PWM values (0-255) for LED brightness control.
    Maps to the LedCtrlHandler.
    """
    
    def get_command_name(self) -> str:
        return "lights"
    
    def _setup_publishers(self) -> None:
        pass  # Uses led_ctrl handler
    
    def handle(self, data: Dict[str, Any]) -> bool:
        """
        Handle lights command with PWM value.
        
        Expected format:
        {
            "command": "lights",
            "data": {"pwm": 66},  # 0-255
            "timestamp": 1234567890.123,
            "source_type": "tele"
        }
        """
        try:
            pwm_value = data.get('pwm', 255)  # Default to full brightness
            
            # Validate PWM range
            if not 0 <= pwm_value <= 255:
                self.logger.warning(f"PWM value {pwm_value} out of range [0-255], clamping")
                pwm_value = max(0, min(255, pwm_value))
            
            # Delegate to LedCtrlHandler to control both lights
            if hasattr(self.node, '_command_registry'):
                led_data = {
                    'chassis_light': float(pwm_value),
                    'camera_light': float(pwm_value)
                }
                return self.node._command_registry.handle_command("led_ctrl", led_data)
            
            self.logger.warning("lights: command registry not available")
            return False
            
        except Exception as e:
            self.logger.error(f"Failed to handle lights command: {e}")
            return False


class CommandRegistry:
    """
    Registry for command handlers.
    
    Maintains a mapping of command names to handler instances.
    Provides methods to register handlers and route commands.
    """
    
    def __init__(self, node: Node):
        """
        Initialize the command registry.
        
        Args:
            node: ROS2 node for creating handlers
        """
        self.node = node
        self.logger = node.get_logger()
        self._handlers: Dict[str, CommandHandler] = {}
        self._mqtt_adapter: Any = None
        self._command_topic: Optional[str] = None
        self._register_default_handlers()
    
    def set_mqtt_context(self, adapter: Any, command_topic: str):
        """Pass MQTT context to all registered handlers."""
        self._mqtt_adapter = adapter
        self._command_topic = command_topic
        for handler in self._handlers.values():
            handler.set_mqtt_context(adapter, command_topic)

    def _register_default_handlers(self) -> None:
        """Register all default command handlers."""
        default_handlers = [
            GenericActuationHandler,  # Generic actuation handler for all command-based control
            LedCtrlHandler,
            LightsCommandHandler,
            EmergencyStopHandler,
            OledCtrlHandler,
            JointTrajectoryHandler,
            GripperHandler,
            StatusQueryHandler,
            BatteryCheckHandler,
            TakePhotoHandler,
            CameraServoHandler,
        ]
        
        for handler_class in default_handlers:
            self.register_handler(handler_class)
            
        # Register specialized camera handlers for start/stop to match FE button
        self.register_handler_instance(CameraCommandHandler(self.node, "start_video"))
        self.register_handler_instance(CameraCommandHandler(self.node, "stop_video"))
    
    def register_handler(self, handler_class: type) -> None:
        """
        Register a command handler class.
        
        Args:
            handler_class: CommandHandler subclass to register
        """
        try:
            handler = handler_class(self.node)
            command_name = handler.get_command_name()
            self._handlers[command_name] = handler
            self.logger.info(f"Registered command handler: {command_name}")
        except Exception as e:
            self.logger.error(f"Failed to register handler {handler_class.__name__}: {e}")
    
    def register_handler_instance(self, handler: CommandHandler) -> None:
        """
        Register an already-instantiated command handler.
        
        Args:
            handler: CommandHandler instance to register
        """
        command_name = handler.get_command_name()
        self._handlers[command_name] = handler
        self.logger.info(f"Registered command handler: {command_name}")
    
    def handle_command(self, command: str, data: Dict[str, Any]) -> bool:
        """
        Route a command to the appropriate handler.
        
        Args:
            command: Command name/type
            data: Command data dictionary
            
        Returns:
            True if command was handled successfully, False otherwise
        """
        if command not in self._handlers:
            self.logger.warning(
                f"No handler registered for command: {command}. "
                f"Available: {list(self._handlers.keys())}"
            )
            return False
        
        handler = self._handlers[command]
        return handler.handle(data)
    
    def get_registered_commands(self) -> list:
        """Get list of all registered command names."""
        return list(self._handlers.keys())
    
    def unregister_handler(self, command_name: str) -> bool:
        """
        Unregister a command handler.
        
        Args:
            command_name: Name of command to unregister
            
        Returns:
            True if handler was found and removed, False otherwise
        """
        if command_name in self._handlers:
            del self._handlers[command_name]
            self.logger.info(f"Unregistered command handler: {command_name}")
            return True
        return False


# Decorator for easy handler registration
def command_handler(command_name: str):
    """
    Decorator for registering command handlers.
    
    Usage:
        @command_handler("my_command")
        class MyCommandHandler(CommandHandler):
            ...
    """
    def decorator(cls):
        cls._command_name = command_name
        return cls
    return decorator

