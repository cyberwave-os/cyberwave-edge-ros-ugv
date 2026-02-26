# Docker Build Instructions

## Build Context

Build from the `mqtt_bridge` directory (not from `docker-conf`):

```bash
cd cyberwave-edge-nodes/cyberwave-ros2/mqtt_bridge

# Build the Docker image
docker build -f docker-conf/Dockerfile -t cyb_ugv_rpi_ros_humble:latest .

# Tag the image for Docker Hub
docker tag cyb_ugv_rpi_ros_humble:latest cyberwaveos/ugv_beast:latest

# Login to Docker Hub (if not already logged in)
docker login

# Push to Docker Hub
docker push cyberwaveos/ugv_beast:latest
```

## What Gets Copied

The build uses `.dockerignore` to exclude:
- `docker-conf/` (Dockerfile and build configs)
- `docs/` (documentation)
- `.env` (environment variables)
- `README.md` (root readme)
- Python cache files (`__pycache__`, `*.pyc`, etc.)
- Build artifacts (`build/`, `dist/`, `install/`, `log/`)

## SSH Access

The container runs OpenSSH on **port 23**:

```bash
# Run with SSH port exposed
docker run -d -p 23:23 --name ugv_container cyb_ugv_rpi_ros_humble:latest

# Set root password (first time)
docker exec -it ugv_container passwd root

# Or copy SSH key
docker exec -it ugv_container bash
# Inside container:
echo "YOUR_PUBLIC_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Connect via SSH
ssh -p 23 root@localhost
```

## Important Notes

- Build context is relative to `mqtt_bridge/` directory
- COPY commands use relative paths (e.g., `COPY . /dest` copies mqtt_bridge content)
- SSH runs on port 23 (not standard port 22)
- Root login is enabled for development purposes
