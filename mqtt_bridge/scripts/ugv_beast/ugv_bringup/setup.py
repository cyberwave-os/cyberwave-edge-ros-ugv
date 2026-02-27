from setuptools import find_packages, setup
import os
from glob import glob

package_name = 'ugv_bringup'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob(os.path.join('launch', '*launch.py'))),
        (os.path.join('share', package_name, 'param'), glob(os.path.join('param', '*.yaml'))),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='dudu',
    maintainer_email='dudu@todo.todo',
    description='UGV Beast bringup: hardware driver and launch files',
    license='Apache-2.0',
    entry_points={
        'console_scripts': [
            'ugv_integrated_driver = ugv_bringup.ugv_integrated_driver:main',
        ],
    },
)
