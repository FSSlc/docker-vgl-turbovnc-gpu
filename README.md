# docker-vgl-turborvnc-gpu

单一 `Dockerfile` 构建完整 Linux 桌面容器，默认使用最小化 XFCE，并通过 TurboVNC 自带 WebSocket/noVNC 集成直接暴露浏览器访问入口。容器内只使用 `root` 用户。

技术路线：

- Intel/AMD: `VirtualGL + TurboVNC + noVNC`，容器通过 `/dev/dri` 访问宿主机 DRM 设备，默认使用 VirtualGL EGL 后端。
- NVIDIA: `VirtualGL + TurboVNC + noVNC`，容器通过 `nvidia-container-toolkit` 暴露 GPU，默认使用 VirtualGL EGL 后端。

镜像本身不区分 GPU 类型。真正决定使用哪块宿主机显卡的是 `docker run` 时暴露给容器的设备和运行参数。

支持的基础发行版：

- `ubuntu2404`
- `ubuntu2204`
- `debian12`
- `rocky9`

## 目录

- `Dockerfile`: 统一多阶段构建入口
- `docker/entrypoint.sh`: 容器入口
- `docker/vnc-start.sh`: TurboVNC/noVNC 启动器
- `docker/xfce-session.sh`: XFCE 会话包装器
- `tests/smoke-contract.sh`: 交付面 smoke 校验
- `docker/install-runtime.sh`: 发行版包安装和 GitHub Release 安装包落地

## 上游来源

- TurboVNC: 通过官方 GitHub Release 安装 `.deb` / `.rpm`
- VirtualGL: 通过官方 GitHub Release 安装 `.deb` / `.rpm`
- noVNC: 通过官方 GitHub 源码归档引入静态页面

## 构建

Ubuntu 24.04:

```bash
docker build \
  -t vgl-desktop:ubuntu2404 \
  --build-arg BASE_DISTRO=ubuntu2404 \
  .
```

Ubuntu 22.04:

```bash
docker build \
  -t vgl-desktop:ubuntu2204 \
  --build-arg BASE_DISTRO=ubuntu2204 \
  .
```

Debian 12:

```bash
docker build \
  -t vgl-desktop:debian12 \
  --build-arg BASE_DISTRO=debian12 \
  .
```

Rocky 9:

```bash
docker build \
  -t vgl-desktop:rocky9 \
  --build-arg BASE_DISTRO=rocky9 \
  .
```

## 宿主机准备

### Intel / AMD

宿主机要求：

- Linux 宿主机已经正常加载 GPU 驱动，并且存在 `/dev/dri`
- `docker` 已安装
- 当前用户有权限运行 Docker

宿主机确认命令：

```bash
ls -l /dev/dri
ls -l /dev/dri/by-path
```

### NVIDIA

宿主机要求：

- Linux 宿主机已经安装 NVIDIA 驱动
- 已安装 `nvidia-container-toolkit`
- Docker 已配置 NVIDIA runtime

官方推荐配置 Docker runtime 的宿主机命令：

```bash
sudo nvidia-ctk runtime configure --runtime=docker --set-as-default
sudo systemctl restart docker
```

宿主机确认命令：

```bash
nvidia-smi
docker info | grep -i runtime
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

## NVIDIA 运行机制

在 NVIDIA 宿主机上，容器和 GPU 的关系分成两层：

1. `docker run --gpus ...` 或 `NVIDIA_VISIBLE_DEVICES` 决定哪块宿主机 NVIDIA GPU 对容器可见。
2. `NVIDIA_DRIVER_CAPABILITIES` 决定哪些驱动能力和用户态库会挂进容器。

对这个项目来说，VirtualGL 负责截获需要远程显示优化的 OpenGL/GLX 路径，随后通过 NVIDIA 驱动提供的 EGL/OpenGL 能力在容器可见的 GPU 上创建离屏渲染上下文，再把图像送回 TurboVNC/Xvnc 桌面。`--gpus all` 只解决“哪块卡可见”，不自动保证 OpenGL 图形栈一定完整可用。

推荐最小图形能力集合：

- `graphics`: OpenGL / Vulkan
- `display`: 需要 X11 display 相关能力时使用
- `utility`: `nvidia-smi` 和 NVML

如果同时还要跑 CUDA/Compute，增加 `compute`。如果不想细分，可以直接使用：

```bash
-e NVIDIA_DRIVER_CAPABILITIES=all
```

## 启动容器

### Intel / AMD，直接使用默认可见的 DRM GPU

```bash
docker run -d \
  --name vgl-desktop \
  --shm-size=1g \
  --device /dev/dri:/dev/dri \
  -e VNC_PASSWORD=changeme \
  -e VGL_DISPLAY=egl0 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:ubuntu2404
```

### Intel / AMD，绑定到宿主机某一块指定显卡

先在宿主机找出目标 GPU 对应的 DRM 节点：

```bash
ls -l /dev/dri/by-path
readlink -f /dev/dri/by-path/pci-0000:03:00.0-render
readlink -f /dev/dri/by-path/pci-0000:03:00.0-card
```

如果目标卡对应的是 `/dev/dri/renderD129` 和 `/dev/dri/card1`，则只把这块卡暴露给容器：

```bash
docker run -d \
  --name vgl-desktop-amd1 \
  --shm-size=1g \
  --device /dev/dri/renderD129:/dev/dri/renderD129 \
  --device /dev/dri/card1:/dev/dri/card1 \
  -e VNC_PASSWORD=changeme \
  -e VGL_DISPLAY=/dev/dri/renderD129 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:ubuntu2404
```

这种方式同样适用于 Intel iGPU 或 AMD dGPU。关键点不是镜像标签，而是你把哪一个 `/dev/dri/*` 节点传给了容器。

### NVIDIA，使用所有可见 NVIDIA GPU

```bash
docker run -d \
  --name vgl-desktop-nvidia \
  --shm-size=1g \
  --gpus all \
  -e NVIDIA_DRIVER_CAPABILITIES=graphics,utility,display \
  -e VNC_PASSWORD=changeme \
  -e VGL_DISPLAY=egl0 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:rocky9
```

### NVIDIA，绑定到宿主机某一块指定显卡

先在宿主机确认 GPU 编号或 UUID：

```bash
nvidia-smi -L
```

绑定第 0 块卡：

```bash
docker run -d \
  --name vgl-desktop-nvidia0 \
  --shm-size=1g \
  --gpus '"device=0"' \
  -e NVIDIA_DRIVER_CAPABILITIES=graphics,utility,display \
  -e VNC_PASSWORD=changeme \
  -e VGL_DISPLAY=egl0 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:rocky9
```

也可以直接按 UUID 绑定：

```bash
docker run -d \
  --name vgl-desktop-nvidia-uuid \
  --shm-size=1g \
  --gpus '"device=GPU-18a3e86f-4c0e-cd9f-59c3-55488c4b0c24"' \
  -e NVIDIA_DRIVER_CAPABILITIES=graphics,utility,display \
  -e VNC_PASSWORD=changeme \
  -e VGL_DISPLAY=egl0 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:rocky9
```

镜像不会“自己挑卡”。Intel/AMD 走 `--device`，NVIDIA 走 `--gpus`，你把哪块卡交给容器，桌面里的 `vglrun` 就只能用到哪块卡。

也可以不用 `--gpus "device=..."`，而是在运行时改用环境变量约束可见 GPU：

```bash
docker run -d \
  --name vgl-desktop-nvidia-env \
  --gpus all \
  -e NVIDIA_VISIBLE_DEVICES=GPU-18a3e86f-4c0e-cd9f-59c3-55488c4b0c24 \
  -e NVIDIA_DRIVER_CAPABILITIES=graphics,display,utility \
  -e VNC_PASSWORD=changeme \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:rocky9
```

更推荐优先使用 `--gpus "device=..."`，语义更直接。

## 浏览器访问

默认显示号是 `:1`，因此：

- noVNC 页面: `http://<host>:5801/vnc.html?host=<host>&port=5801`
- 原生 VNC 端口: `<host>:5901`

在 noVNC 页面输入 `VNC_PASSWORD` 对应的密码即可登录。

## 容器内运行 3D 程序

进入容器：

```bash
docker exec -it vgl-desktop bash
```

先检查 VirtualGL 能否看到 EGL 设备：

```bash
eglinfo egl0
eglinfo -e
```

运行示例 OpenGL 程序：

```bash
vglrun -d "${VGL_DISPLAY:-egl0}" glxgears -info
```

如果你是从浏览器登录桌面，也可以在桌面里的终端直接运行：

```bash
vglrun -d "${VGL_DISPLAY:-egl0}" glxgears -info
```

实际业务程序同理：

```bash
vglrun -d "${VGL_DISPLAY:-egl0}" /path/to/your-3d-app
```

### NVIDIA 下的 GLX 应用

大多数传统 Linux 3D GUI 程序属于这一类。推荐启动方式：

```bash
export DISPLAY=:1
export VGL_DISPLAY=egl0
export VGL_COMPRESS=proxy
vglrun -d "${VGL_DISPLAY}" glxinfo -B
vglrun -d "${VGL_DISPLAY}" glxgears -info
vglrun -d "${VGL_DISPLAY}" /path/to/your-glx-app
```

通常不需要额外执行某个“启用 NVIDIA”命令。关键前提只有三个：

- 宿主机 NVIDIA 驱动正常
- 容器通过 `--gpus ...` 拿到了目标 GPU
- `NVIDIA_DRIVER_CAPABILITIES` 至少包含 `graphics`

### NVIDIA 下的原生 EGL 应用

如果应用本身就是纯 EGL 离屏渲染程序，它在很多情况下即使不走 `vglrun` 也能直接使用容器里可见的 NVIDIA GPU，因为 `--gpus ...` 已经把所需设备和驱动库暴露给了容器。

但如果应用是“原生 EGL + 窗口显示”，是否能完全按 `VirtualGL + TurboVNC` 链路稳定工作，要看应用如何创建 surface、窗口和上下文。VirtualGL 的 EGL 后端本质上是在没有 3D X server 的情况下，用 EGL + DRI device 替代传统 GLX 访问路径；它能覆盖大多数常见远程 3D 场景，但兼容性不如最传统的 GLX 路线绝对。

建议验证顺序：

```bash
nvidia-smi
eglinfo -e
eglinfo egl0
vglrun -d egl0 glxinfo -B
```

如果 `nvidia-smi` 正常、`eglinfo -e` 能列出 NVIDIA EGL 设备，而你的原生 EGL 应用仍然失败，优先检查的是应用自身的 EGL 平台选择逻辑，而不是 TurboVNC。

### 常用环境变量

- `VGL_DISPLAY=egl0`: 推荐默认值，让 VirtualGL 走 EGL 后端
- `VGL_COMPRESS=proxy`: 与 TurboVNC/X proxy 组合时的常见选择
- `DISPLAY=:1`: TurboVNC/Xvnc 桌面显示号
- `NVIDIA_DRIVER_CAPABILITIES=graphics,display,utility`: NVIDIA 图形桌面的推荐最小集合
- `NVIDIA_DRIVER_CAPABILITIES=all`: 想减少 capability 维度排障时可直接使用
- `NVIDIA_VISIBLE_DEVICES=<index|uuid>`: 按环境变量限制容器可见 GPU，`--gpus "device=..."` 更推荐

### 排障步骤

1. 宿主机先执行 `nvidia-smi`，确认驱动正常。
2. 用测试容器执行 `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`，确认 Docker 运行时正常。
3. 进入本容器执行 `nvidia-smi`，确认目标 GPU 已挂入容器。
4. 执行 `eglinfo -e` 和 `eglinfo egl0`，确认 EGL 设备可见。
5. 执行 `vglrun -d egl0 glxinfo -B`，确认 VirtualGL 能通过 EGL 后端创建 OpenGL 上下文。
6. 最后再运行真实应用。

## 关键环境变量

- `BASE_DISTRO`: `ubuntu2404|ubuntu2204|debian12|rocky9`
- `VNC_DISPLAY`: 默认 `:1`
- `VNC_GEOMETRY`: 默认 `1920x1080`
- `VNC_DEPTH`: 默认 `24`
- `VNC_PASSWORD`: 默认 `root`
- `VGL_DISPLAY`: 默认 `egl0`
- `VNC_EXTRA_ARGS`: 透传给 `/opt/TurboVNC/bin/vncserver`

修改分辨率示例：

```bash
docker run -d \
  --name vgl-desktop-4k \
  --shm-size=1g \
  --device /dev/dri:/dev/dri \
  -e VNC_PASSWORD=changeme \
  -e VNC_GEOMETRY=2560x1440 \
  -p 5801:5801 \
  -p 5901:5901 \
  vgl-desktop:ubuntu2404
```

## 运行机制

1. 容器入口脚本写入 `/root/.vnc/passwd`
2. TurboVNC 启动 `:1` 桌面并拉起 `xfce`
3. `-novnc /opt/noVNC` 开启内置 WebSocket/noVNC 页面
4. 3D 程序使用 `vglrun` 将 OpenGL 渲染重定向到宿主机 GPU
5. VirtualGL 通过 X11 transport 将图像送入 TurboVNC 会话，再由 noVNC 在浏览器展示

## 已知边界

- 项目默认使用 VirtualGL EGL 后端，优先减少容器内额外 Xorg 配置和镜像体积。
- 某些只在 GLX 路径上工作的老程序，可能需要你在运行时覆盖 `VGL_DISPLAY` 或自行扩展为专用 Xorg/GLX 路线。
- Intel/AMD 路线依赖宿主机 `/dev/dri` 可用；NVIDIA 路线依赖 `nvidia-container-toolkit`。
