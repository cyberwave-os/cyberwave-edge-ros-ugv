# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-02-05

### Added
- Initial release of Cyberwave Edge ROS2
- Bidirectional ROS 2 ↔ MQTT bridge
- Cyberwave SDK integration
- Rate limiting for upstream traffic (100 Hz → 1 Hz)
- Joint state mapping and transformation
- Source type filtering for downstream commands
- WebRTC video streaming support
- Internal odometry calculation
- Navigation Stack (Nav2) integration
- Pluggable command registry system
- Support for multiple robot configurations:
  - `default`: Generic configuration
  - `robot_arm_v1`: Robotic arms (UR series)
  - `robot_ugv_beast_v1`: UGV platforms
- Systemd service for auto-start on boot
- Installation and uninstallation scripts
- Comprehensive documentation
- Test suite foundation

### Configuration
- Environment-based configuration via `.env`
- YAML-based robot mapping system
- Configurable MQTT broker settings
- Adjustable rate limiting

### Documentation
- Main README with quick start guide
- Installation instructions
- Configuration guide
- Troubleshooting guide
- Contributing guidelines
- API documentation placeholders

[Unreleased]: https://github.com/cyberwave-os/cyberwave-edge-ros/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/cyberwave-os/cyberwave-edge-ros/releases/tag/v0.1.0
