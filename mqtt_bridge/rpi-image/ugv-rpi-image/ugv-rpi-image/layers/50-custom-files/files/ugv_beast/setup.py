"""
UGV Bringup Package Setup
This is a PLACEHOLDER - replace with your actual setup.py

Expected location in image:
  /home/ubuntu/ws/ugv_ws/src/ugv_main/ugv_bringup/setup.py
"""

from setuptools import setup
import os
from glob import glob

package_name = 'ugv_bringup'

setup(
    name=package_name,
    version='1.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'),
            glob('launch/*.launch.py')),
        (os.path.join('share', package_name, 'config'),
            glob('config/*.yaml')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='ubuntu',
    maintainer_email='ubuntu@ugv.local',
    description='UGV Bringup Package',
    license='Apache License 2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'ugv_integrated_driver = ugv_bringup.ugv_integrated_driver:main',
        ],
    },
)
