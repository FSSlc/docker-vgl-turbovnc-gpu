#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}").." && pwd)"

echo "Building image..."
docker build -t vnc-test:latest "${ROOT_DIR}"

echo "Starting container..."
container_id=$(docker run -d \
  -e VNC_PASSWORD=testpass123 \
  -e VNC_DISPLAY=:1 \
  -e VNC_GEOMETRY=1920x1080 \
  -p 5901:5901 \
  vnc-test:latest)

cleanup() {
  echo "Cleaning up..."
  docker stop "${container_id}" >/dev/null 2>&1 || true
  docker rm "${container_id}" >/dev/null 2>&1 || true
  docker rmi vnc-test:latest >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Waiting for services..."
for i in {1..30}; do
  if docker exec "${container_id}" pgrep -f Xvnc >/dev/null 2>&1; then
    echo "VNC server started"
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: Timeout waiting for VNC server" >&2
    docker logs "${container_id}"
    exit 1
  fi
  sleep 1
done

echo "Testing VNC connection..."
if ! docker exec "${container_id}" pgrep -f Xvnc >/dev/null 2>&1; then
  echo "ERROR: VNC server not running" >&2
  docker logs "${container_id}"
  exit 1
fi

echo "Testing Xfce session..."
if ! docker exec "${container_id}" pgrep -f xfce4-session >/dev/null 2>&1; then
  echo "ERROR: Xfce not running" >&2
  docker logs "${container_id}"
  exit 1
fi

echo "Testing VirtualGL..."
if ! docker exec "${container_id}" /opt/VirtualGL/bin/vglrun --version >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not working" >&2
  exit 1
fi

echo "Testing TurboVNC..."
if ! docker exec "${container_id}" /opt/TurboVNC/bin/Xvnc -version >/dev/null 2>&1; then
  echo "ERROR: TurboVNC not working" >&2
  exit 1
fi

echo "✅ Integration tests passed"
