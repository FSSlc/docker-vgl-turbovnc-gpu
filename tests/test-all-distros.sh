#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}").." && pwd)"

# 支持的发行版列表
DISTROS=(
  "ubuntu2404"
  "ubuntu2204"
  "debian13"
  "debian12"
  "rocky9"
  "rocky8"
  "alma9"
  "alma8"
  "fedora40"
  "fedora39"
)

echo "Testing all supported distributions..."
echo "======================================"

failed_distros=()
success_count=0

for distro in "${DISTROS[@]}"; do
  echo ""
  echo "Testing ${distro}..."
  echo "--------------------"

  if docker build \
    -t "vgl-desktop-test:${distro}" \
    --build-arg BASE_DISTRO="${distro}" \
    "${ROOT_DIR}" >/dev/null 2>&1; then
    echo "✅ ${distro}: Build successful"
    ((success_count++))

    # 清理测试镜像
    docker rmi "vgl-desktop-test:${distro}" >/dev/null 2>&1 || true
  else
    echo "❌ ${distro}: Build failed"
    failed_distros+=("${distro}")
  fi
done

echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total: ${#DISTROS[@]}"
echo "Success: ${success_count}"
echo "Failed: ${#failed_distros[@]}"

if [[ ${#failed_distros[@]} -gt 0 ]]; then
  echo ""
  echo "Failed distributions:"
  for distro in "${failed_distros[@]}"; do
    echo "  - ${distro}"
  done
  exit 1
fi

echo ""
echo "✅ All distributions tested successfully!"
