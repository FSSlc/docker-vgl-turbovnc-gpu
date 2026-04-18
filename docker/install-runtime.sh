#!/usr/bin/env bash

set -euo pipefail

: "${TURBOVNC_VERSION:=3.3.1}"
: "${VIRTUALGL_VERSION:=3.1.4}"

. /etc/os-release

install_debian_family() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates \
    dbus-x11 \
    fontconfig \
    libegl1 \
    libgl1 \
    libglu1-mesa \
    mesa-utils \
    procps \
    x11-xserver-utils \
    xauth \
    xfce4 \
    xfce4-terminal \
    xterm
  apt-get install -y --no-install-recommends \
    "/tmp/artifacts/deb/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" \
    "/tmp/artifacts/deb/turbovnc_${TURBOVNC_VERSION}_amd64.deb"
  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

install_rocky_family() {
  dnf -y install dnf-plugins-core epel-release
  dnf config-manager --set-enabled crb
  dnf -y install \
    ca-certificates \
    dbus-x11 \
    dejavu-sans-fonts \
    fontconfig \
    mesa-demos \
    mesa-libEGL \
    mesa-libGL \
    mesa-libGLU \
    procps-ng \
    thunar \
    xauth \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xfce4-terminal \
    xfdesktop \
    xorg-x11-xauth \
    xorg-x11-xinit \
    xorg-x11-xsetroot \
    xterm \
    xfwm4
  dnf -y install \
    "/tmp/artifacts/rpm/VirtualGL-${VIRTUALGL_VERSION}.x86_64.rpm" \
    "/tmp/artifacts/rpm/turbovnc-${TURBOVNC_VERSION}.x86_64.rpm"
  dnf clean all
  rm -rf /var/cache/dnf
}

case "${ID}" in
  ubuntu|debian)
    install_debian_family
    ;;
  rocky)
    install_rocky_family
    ;;
  *)
    echo "unsupported base distro: ${ID}" >&2
    exit 1
    ;;
esac

mkdir -p /opt/noVNC
cp -a /tmp/artifacts/noVNC/. /opt/noVNC/
ln -sf /opt/noVNC/vnc.html /opt/noVNC/index.html
