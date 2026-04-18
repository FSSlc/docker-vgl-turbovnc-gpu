#!/usr/bin/env bash

set -euo pipefail

export HOME=/root
export USER=root
export LOGNAME=root
export PATH="/opt/TurboVNC/bin:/opt/VirtualGL/bin:${PATH}"

display_number="${VNC_DISPLAY#:}"

/opt/TurboVNC/bin/vncserver -kill "${VNC_DISPLAY}" >/dev/null 2>&1 || true
rm -f "/tmp/.X${display_number}-lock" "/tmp/.X11-unix/X${display_number}"

cat > /root/.vnc/xstartup.turbovnc <<'EOF'
#!/usr/bin/env bash
exec /opt/container/xfce-session.sh
EOF
chmod +x /root/.vnc/xstartup.turbovnc

args=(
  "${VNC_DISPLAY}"
  -fg
  -geometry "${VNC_GEOMETRY}"
  -depth "${VNC_DEPTH}"
  -wm xfce
  -novnc "${VNC_NOVNC_DIR}"
  -localhost no
)

if [[ -n "${VNC_EXTRA_ARGS:-}" ]]; then
  read -r -a extra_args <<< "${VNC_EXTRA_ARGS}"
  args+=("${extra_args[@]}")
fi

exec /opt/TurboVNC/bin/vncserver "${args[@]}"
