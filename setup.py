from setuptools import setup
import os
from glob import glob

package_name = 'mqtt_bridge'

setup(
    name=package_name,
    version='0.1.0',
    packages=[package_name, package_name + '.plugins'],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/config',
            glob('mqtt_bridge/config/*.yaml')),
        ('share/' + package_name + '/config/mappings',
            glob('mqtt_bridge/config/mappings/*.yaml')),
        ('share/' + package_name + '/launch',
            glob('launch/*.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Cyberwave',
    maintainer_email='info@cyberwave.com',
    description='ROS2 MQTT bridge for Cyberwave digital twin platform',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'mqtt_bridge_node = mqtt_bridge.mqtt_bridge_node:main',
        ],
    },
)
