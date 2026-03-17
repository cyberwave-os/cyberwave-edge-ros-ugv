#!/usr/bin/env python3
import serial
import json
import queue
import threading
import rclpy
from rclpy.node import Node
import logging
import time
from std_msgs.msg import Header, Float32MultiArray, Float32
from geometry_msgs.msg import Twist
from sensor_msgs.msg import Imu, MagneticField, JointState
import math
import os
import subprocess

def is_jetson():
    # Check for Jetson-specific files or environment
    result = any("ugv_jetson" in root for root, dirs, files in os.walk("/"))
    return result

if is_jetson():
    serial_port = '/dev/ttyTHS1'
else:
    serial_port = '/dev/ttyAMA0'

# Helper class for reading lines from a serial port
class ReadLine:
    def __init__(self, s):
        self.buf = bytearray()  # Buffer to store incoming data
        self.s = s  # Serial object

    # Read a line of data from the serial input
    def readline(self):
        i = self.buf.find(b"\n")
        if i >= 0:
            r = self.buf[:i+1]
            self.buf = self.buf[i+1:]
            return r
        while True:
            try:
                i = max(1, min(512, self.s.in_waiting))  # Read from serial buffer
                data = self.s.read(i)
                i = data.find(b"\n")
                if i >= 0:
                    r = self.buf + data[:i+1]
                    self.buf[0:] = data[i+1:]
                    return r
                else:
                    self.buf.extend(data)
            except Exception:
                return b""

    # Clear the buffer
    def clear_buffer(self):
        self.s.reset_input_buffer()

# Base controller class for managing UART communication and processing commands
class BaseController:
    def __init__(self, uart_dev_set, baud_set):
        self.logger = logging.getLogger('BaseController')  # Logger setup
        self.ser = serial.Serial(uart_dev_set, baud_set, timeout=1)  # Open serial connection
        self.rl = ReadLine(self.ser)  # Initialize ReadLine helper
        self.command_queue = queue.Queue()  # Command queue for sending data
        self.command_thread = threading.Thread(target=self.process_commands, daemon=True)  # Start a separate thread for processing commands
        self.command_thread.start()
        self.data_buffer = None  # Buffer for holding received data
        # Base data structure to hold sensor values
        self.base_data = {"T": 1001, "L": 0, "R": 0, "ax": 0, "ay": 0, "az": 0, "gx": 0, "gy": 0, "gz": 0, "mx": 0, "my": 0, "mz": 0, "odl": 0, "odr": 0, "v": 0}
    
    # Function to read and return feedback data from the serial input
    def feedback_data(self):
        try:
            line_bytes = self.rl.readline()
            if not line_bytes:
                return None
            try:
                line = line_bytes.decode('utf-8')  # Read line from UART
            except UnicodeDecodeError:
                # Silently clear buffer on decoding errors (likely serial noise)
                self.rl.clear_buffer()
                return None
                
            self.data_buffer = json.loads(line)  # Parse JSON data
            self.base_data = self.data_buffer  # Store received data
            return self.base_data  # Return base data
        except json.JSONDecodeError:
            self.rl.clear_buffer()  # Clear buffer on error
        except Exception as e:
            self.logger.error(f"[base_ctrl.feedback_data] unexpected error: {e}")
            self.rl.clear_buffer()

    # Receive and decode data from the serial connection
    def on_data_received(self):
        self.ser.reset_input_buffer()
        data_read = json.loads(self.rl.readline().decode('utf-8'))  # Read and parse JSON data
        return data_read

    # Add a command to the queue to be sent via UART
    def send_command(self, data):
        self.command_queue.put(data)

    # Thread function to process and send commands from the queue
    def process_commands(self):
        while True:
            data = self.command_queue.get()  # Get command from the queue
            self.ser.write((json.dumps(data) + '\n').encode("utf-8"))  # Send command as JSON over UART

    # Send control data as JSON via UART
    def base_json_ctrl(self, input_json):
        self.send_command(input_json)

# ROS node class for bringing up the UGV system and publishing sensor data
class ugv_bringup_node(Node):
    def __init__(self):
        super().__init__('ugv_bringup')
        # Publishers for IMU data, magnetic field data, odometry, and voltage
        self.imu_data_raw_publisher_ = self.create_publisher(Imu, "imu/data_raw", 100)
        self.imu_mag_publisher_ = self.create_publisher(MagneticField, "imu/mag", 100)
        self.odom_publisher_ = self.create_publisher(Float32MultiArray, "odom/odom_raw", 100)
        self.voltage_publisher_ = self.create_publisher(Float32, "voltage", 50)

        # Subscribers for control commands
        self.cmd_vel_sub_ = self.create_subscription(Twist, "cmd_vel", self.cmd_vel_callback, 10)
        self.joint_states_sub = self.create_subscription(JointState, 'ugv/joint_states', self.joint_states_callback, 10)
        self.led_ctrl_sub = self.create_subscription(Float32MultiArray, 'ugv/led_ctrl', self.led_ctrl_callback, 10)
        
        # Initialize the base controller with the UART port and baud rate
        self.base_controller = BaseController(serial_port, 115200)
        # Timer to periodically execute the feedback loop (20Hz to prevent CPU overload)
        self.feedback_timer = self.create_timer(0.05, self.feedback_loop)

    # Callback for processing velocity commands
    def cmd_vel_callback(self, msg):
        linear_velocity = msg.linear.x
        angular_velocity = msg.angular.z
        if linear_velocity == 0:
            if 0 < angular_velocity < 0.2:
                angular_velocity = 0.2
            elif -0.2 < angular_velocity < 0:
                angular_velocity = -0.2
        data = {'T': '13', 'X': linear_velocity, 'Z': angular_velocity}
        self.base_controller.send_command(data)

    # Callback for processing joint state updates
    def joint_states_callback(self, msg):
        # Only process commands from teleoperation-style sources
        source_type = msg.header.frame_id
        if source_type not in ('tele', 'sim_tele'):
            return

        name = msg.name
        position = msg.position
        try:
            x_rad = position[name.index('pt_base_link_to_pt_link1')]
            y_rad = position[name.index('pt_link1_to_pt_link2')]
            # Convert to integers - STM32 JSON parser expects int, not float
            x_degree = int((180 * x_rad) / 3.1415926)
            y_degree = int((180 * y_rad) / 3.1415926)
            joint_data = {'T': 134, 'X': x_degree, 'Y': y_degree, "SX": 600, "SY": 600}
            self.get_logger().info(f"[PT_SERVO] Sending to UART: {joint_data}")
            self.base_controller.send_command(joint_data)
        except (ValueError, IndexError) as e:
            self.get_logger().warning(f"[PT_SERVO] Failed to extract joint positions: {e}")
            pass

    # Callback for processing LED control commands
    def led_ctrl_callback(self, msg):
        if len(msg.data) >= 2:
            led_ctrl_data = {'T': 132, "IO4": msg.data[0], "IO5": msg.data[1]}
            self.base_controller.send_command(led_ctrl_data)

    # Main loop for reading sensor feedback and publishing it to ROS topics
    def feedback_loop(self):
        data = self.base_controller.feedback_data()
        # Fix: Ensure data is a dict before calling .get()
        if data and isinstance(data, dict) and data.get("T") == 1001:
            self.publish_imu_data_raw()
            self.publish_imu_mag()
            self.publish_odom_raw()
            self.publish_voltage()

    # Publish IMU data to the ROS topic "imu/data_raw"
    def publish_imu_data_raw(self):
        msg = Imu()
        msg.header = Header()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = "base_imu_link"
        imu_raw_data = self.base_controller.base_data
        msg.linear_acceleration.x = 9.8 * float(imu_raw_data["ax"]) / 8192
        msg.linear_acceleration.y = 9.8 * float(imu_raw_data["ay"]) / 8192
        msg.linear_acceleration.z = 9.8 * float(imu_raw_data["az"]) / 8192
        msg.angular_velocity.x = 3.1415926 * float(imu_raw_data["gx"]) / (16.4 * 180)
        msg.angular_velocity.y = 3.1415926 * float(imu_raw_data["gy"]) / (16.4 * 180)
        msg.angular_velocity.z = 3.1415926 * float(imu_raw_data["gz"]) / (16.4 * 180)
        self.imu_data_raw_publisher_.publish(msg)
        
    def publish_imu_mag(self):
        msg = MagneticField()
        msg.header = Header()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = "base_imu_link"
        imu_raw_data = self.base_controller.base_data
        # Handle missing magnetometer data gracefully (some hardware doesn't have mag sensor)
        try:
            msg.magnetic_field.x = float(imu_raw_data.get("mx", 0)) * 0.15
            msg.magnetic_field.y = float(imu_raw_data.get("my", 0)) * 0.15
            msg.magnetic_field.z = float(imu_raw_data.get("mz", 0)) * 0.15
        except (KeyError, TypeError, ValueError):
            # If magnetometer data is unavailable, publish zeros
            msg.magnetic_field.x = 0.0
            msg.magnetic_field.y = 0.0
            msg.magnetic_field.z = 0.0
        self.imu_mag_publisher_.publish(msg)

    def publish_odom_raw(self):
        odom_raw_data = self.base_controller.base_data
        array = [float(odom_raw_data["odl"])/100, float(odom_raw_data["odr"])/100]
        msg = Float32MultiArray(data=array)
        self.odom_publisher_.publish(msg)

    def publish_voltage(self):
        voltage_data = self.base_controller.base_data
        voltage_value = float(voltage_data["v"])/100
        msg = Float32()
        msg.data = voltage_value
        self.voltage_publisher_.publish(msg)

        # Audio alert for low battery
        if 0.1 < voltage_value < 9:
            try:
                # Using local workspace path
                wav_path = '/home/ws/ugv_ws/src/ugv_main/ugv_bringup/ugv_bringup/low_battery.wav'
                subprocess.run(['aplay', '-D', 'plughw:3,0', wav_path])
                time.sleep(5)
            except Exception:
                pass
                        
def main(args=None):
    rclpy.init(args=args)
    node = ugv_bringup_node()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
