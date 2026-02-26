# Contributing to Cyberwave Edge ROS2

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Development Setup

### Prerequisites

1. **ROS 2 Humble** or higher
2. **Python 3.9+**
3. **Git**
4. **Development tools**:
   ```bash
   sudo apt install python3-pip python3-venv build-essential
   ```

### Setting Up Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/cyberwave-os/cyberwave-edge-ros.git
   cd cyberwave-edge-ros
   ```

2. **Install dependencies**:
   ```bash
   # ROS 2 dependencies
   rosdep install --from-paths . --ignore-src -r -y
   
   # Python dependencies (including dev tools)
   pip install -r requirements-dev.txt
   ```

3. **Create development environment**:
   ```bash
   # Source ROS 2
   source /opt/ros/humble/setup.bash
   
   # Build workspace
   colcon build --symlink-install
   source install/setup.bash
   ```

4. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your development credentials
   ```

## Code Style

### Python Style Guide

We follow PEP 8 with some modifications:

- **Line length**: 100 characters (not 79)
- **Quotes**: Double quotes for strings
- **Imports**: Grouped and sorted
  - Standard library
  - Third-party libraries
  - ROS 2 packages
  - Local modules

### Formatting Tools

Use these tools before committing:

```bash
# Format code with black
black mqtt_bridge/ tests/

# Check with flake8
flake8 mqtt_bridge/ tests/

# Type checking with mypy
mypy mqtt_bridge/

# Or use ruff for all-in-one
ruff check mqtt_bridge/ tests/
ruff format mqtt_bridge/ tests/
```

### ROS 2 Conventions

- Use ROS 2 naming conventions (snake_case for topics, CamelCase for services)
- Follow ROS 2 message standards (REP 103, REP 105)
- Include proper documentation strings for nodes and parameters

## Testing

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=mqtt_bridge --cov-report=html

# Run specific test
pytest tests/test_bridge.py -v

# Run tests in parallel
pytest -n auto
```

### Writing Tests

- Place tests in `tests/` directory
- Name test files `test_*.py`
- Use descriptive test names: `test_rate_limiter_reduces_frequency()`
- Include docstrings explaining what the test validates
- Mock external dependencies (MQTT, ROS topics)

Example:
```python
import pytest
from mqtt_bridge.rate_limiter import RateLimiter


def test_rate_limiter_blocks_rapid_messages():
    """Test that rate limiter blocks messages within the limit window."""
    limiter = RateLimiter(limit=1.0)
    
    # First message should pass
    assert limiter.should_publish("topic1") is True
    
    # Second message within 1 second should be blocked
    assert limiter.should_publish("topic1") is False
```

## Pull Request Process

### Before Submitting

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**:
   - Write clear, concise commit messages
   - Keep commits focused and atomic
   - Include tests for new features

3. **Run quality checks**:
   ```bash
   # Format code
   ruff format .
   
   # Run linter
   ruff check .
   
   # Run tests
   pytest
   
   # Build package
   colcon build
   ```

4. **Update documentation**:
   - Update README.md if adding features
   - Add docstrings to new functions/classes
   - Update relevant docs in `docs/`

### Submitting Pull Request

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**:
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changes you made and why
   - Include screenshots/videos for UI changes

3. **PR Template**:
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Tests pass locally
   - [ ] Added new tests
   - [ ] Manual testing completed
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] No new warnings
   ```

### Review Process

- Maintainers will review your PR
- Address any feedback or requested changes
- Once approved, your PR will be merged

## Project Structure

```
cyberwave-edge-ros/
├── mqtt_bridge/           # Main package
│   ├── __init__.py
│   ├── mqtt_bridge_node.py  # Main node
│   ├── config/            # Configuration files
│   │   ├── params.yaml
│   │   └── mappings/      # Robot configurations
│   └── plugins/           # Robot-specific plugins
├── tests/                 # Test suite
├── docs/                  # Documentation
├── scripts/               # Installation scripts
├── launch/                # ROS 2 launch files
└── resource/              # ROS 2 resources
```

## Areas for Contribution

### High Priority

- [ ] Improve test coverage
- [ ] Add more robot configurations
- [ ] Performance optimizations
- [ ] Documentation improvements

### Features

- [ ] Multi-robot coordination
- [ ] Advanced sensor fusion
- [ ] Dynamic reconfiguration
- [ ] Enhanced monitoring dashboard

### Documentation

- [ ] Tutorial videos
- [ ] Setup guides for specific robots
- [ ] API documentation
- [ ] Architecture diagrams

## Communication

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Security**: Email security@cyberwave.com for security issues

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 License.

## Recognition

Contributors will be acknowledged in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to Cyberwave Edge ROS2!
