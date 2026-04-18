#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_file() {
  local path="$1"
  if [[ ! -f "${ROOT_DIR}/${path}" ]]; then
    echo "missing file: ${path}" >&2
    exit 1
  fi
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  if ! grep -Fq -- "${pattern}" "${ROOT_DIR}/${path}"; then
    echo "missing pattern in ${path}: ${pattern}" >&2
    exit 1
  fi
}

assert_file Dockerfile
assert_file README.md
assert_file docker/entrypoint.sh
assert_file docker/vnc-start.sh
assert_file docker/xfce-session.sh

assert_contains Dockerfile "ARG BASE_DISTRO="
assert_contains Dockerfile "FROM downloader AS artifacts"
assert_contains Dockerfile "github.com/VirtualGL/virtualgl/releases/download"
assert_contains Dockerfile "github.com/TurboVNC/turbovnc/releases/download"
assert_contains Dockerfile "ENTRYPOINT [\"/opt/container/entrypoint.sh\"]"

assert_contains README.md "BASE_DISTRO"
assert_contains README.md "--device /dev/dri"
assert_contains README.md "device=0"
assert_contains README.md "/dev/dri/by-path"
assert_contains README.md "noVNC"
assert_contains README.md "vglrun"
assert_contains README.md "nvidia-smi -L"
assert_contains README.md "NVIDIA_DRIVER_CAPABILITIES"
assert_contains README.md "glxinfo -B"
assert_contains README.md "eglinfo -e"
assert_contains README.md "NVIDIA_VISIBLE_DEVICES"

assert_contains docker/entrypoint.sh "VNC_PASSWORD"
assert_contains docker/vnc-start.sh "-novnc"
assert_contains docker/vnc-start.sh "-wm xfce"
assert_contains docker/xfce-session.sh "xfce4-session"

if grep -Fq -- "GPU_STACK" "${ROOT_DIR}/Dockerfile"; then
  echo "unexpected GPU_STACK in Dockerfile" >&2
  exit 1
fi

if grep -Fq -- "GPU_STACK" "${ROOT_DIR}/README.md"; then
  echo "unexpected GPU_STACK in README.md" >&2
  exit 1
fi

echo "smoke-contract: ok"
