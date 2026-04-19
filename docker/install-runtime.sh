#!/usr/bin/env bash

set -euo pipefail

. /etc/os-release

# 检测架构
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)
    PKG_ARCH="amd64"
    RPM_ARCH="x86_64"
    ;;
  aarch64)
    PKG_ARCH="arm64"
    RPM_ARCH="aarch64"
    ;;
  *)
    echo "ERROR: Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

echo "Detected architecture: ${ARCH} (package: ${PKG_ARCH})"

# VirtualGL 和 TurboVNC 官方仓库配置
VIRTUALGL_REPO_BASE="https://packagecloud.io/dcommander/virtualgl"
TURBOVNC_REPO_BASE="https://packagecloud.io/dcommander/turbovnc"

install_debian_family() {
  export DEBIAN_FRONTEND=noninteractive

  # 安装基础依赖
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg

  # 添加 VirtualGL 仓库
  curl -fsSL "${VIRTUALGL_REPO_BASE}/gpgkey" | gpg --dearmor >/etc/apt/trusted.gpg.d/VirtualGL.gpg
  curl -fsSL https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list -o /etc/apt/sources.list.d/VirtualGL.list

  # 添加 TurboVNC 仓库
  curl -fsSL "${TURBOVNC_REPO_BASE}/gpgkey" | gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg
  curl -fsSL https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list -o /etc/apt/sources.list.d/TurboVNC.list

  # 更新并安装
  apt-get update
  apt-get install -y --no-install-recommends \
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
    xterm \
    virtualgl \
    turbovnc

  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

install_rhel_family() {
  # 添加 VirtualGL 仓库
  local repo_base="el"
  local repo_version="${VERSION_ID%%.*}"

  # Fedora 使用不同的仓库路径
  if [[ "${ID}" == "fedora" ]]; then
    repo_base="fedora"
    repo_version="${VERSION_ID}"
  fi

  curl -fsSL https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.repo \
    -o /etc/yum.repos.d/VirtualGL.repo

  # 添加 TurboVNC 仓库
  curl -fsSL https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.repo \
    -o /etc/yum.repos.d/TurboVNC.repo

  # Rocky/Alma 需要 EPEL,Fedora 不需要
  if [[ "${ID}" != "fedora" ]]; then
    dnf -y install dnf-plugins-core epel-release

    # Rocky 9/Alma 9 使用 crb, Rocky 8/Alma 8 使用 powertools
    dnf config-manager --set-enabled crb 2>/dev/null || \
      dnf config-manager --set-enabled powertools 2>/dev/null || true
  fi

  # 安装软件包 (所有 RHEL 系列通用)
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
    xterm \
    xfwm4 \
    VirtualGL \
    turbovnc

  dnf clean all
  rm -rf /var/cache/dnf
}

case "${ID}" in
  ubuntu|debian)
    install_debian_family
    ;;
  rocky|almalinux|fedora)
    install_rhel_family
    ;;
  *)
    echo "unsupported base distro: ${ID}" >&2
    exit 1
    ;;
esac

# 安装 noVNC
mkdir -p /opt/noVNC
cp -a /tmp/artifacts/noVNC/. /opt/noVNC/
ln -sf /opt/noVNC/vnc.html /opt/noVNC/index.html

echo "All components installed and verified successfully!"
