#!/usr/bin/env bash

set -euo pipefail

export HOME=/root
export USER=root
export LOGNAME=root
export SHELL=/bin/bash
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=xfce
export XDG_CURRENT_DESKTOP=XFCE
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-root}"
export XKL_XMODMAP_DISABLE=1

mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

if command -v dbus-launch >/dev/null 2>&1; then
  exec dbus-launch --exit-with-session xfce4-session
fi

exec xfce4-session
