# GitHub Actions 工作流说明

本项目使用 GitHub Actions 自动构建和发布 Docker 镜像到 GitHub Container Registry (ghcr.io)。

## 工作流概览

### 1. Build and Push (`build-and-push.yml`)

**触发条件:**
- Push 到 `main` 或 `develop` 分支
- 创建版本标签 (如 `v1.0.0`)
- Pull Request 到 `main` 分支
- 手动触发 (workflow_dispatch)

**功能:**
- 构建所有支持的 Linux 发行版镜像
- 支持多架构: **linux/amd64** 和 **linux/arm64**
- 推送到 GitHub Container Registry
- 自动生成版本标签
- 缓存构建层以加速后续构建

**镜像标签格式:**
```
ghcr.io/{owner}/{repo}:{distro}-latest
ghcr.io/{owner}/{repo}:{distro}-{version}
ghcr.io/{owner}/{repo}:{distro}-{sha}
```

**支持的架构:**
- `linux/amd64` (x86_64) - Intel/AMD 处理器
- `linux/arm64` (aarch64) - ARM 处理器 (Apple Silicon, AWS Graviton, 树莓派)

**示例:**
```
ghcr.io/username/docker-vgl-turborvnc-gpu:ubuntu2404-latest
ghcr.io/username/docker-vgl-turborvnc-gpu:ubuntu2404-1.0.0
ghcr.io/username/docker-vgl-turborvnc-gpu:ubuntu2404-abc1234
```

---

### 2. Test All Distributions (`test-distros.yml`)

**触发条件:**
- Pull Request 到 `main` 或 `develop` 分支
- 每周一凌晨 2 点自动运行
- 手动触发

**功能:**
- 测试所有发行版的构建
- 验证 VirtualGL 和 TurboVNC 安装
- 测试容器入口点

---

### 3. Release (`release.yml`)

**触发条件:**
- 推送版本标签 (如 `v1.0.0`)

**功能:**
- 创建 GitHub Release
- 生成变更日志
- 提供使用说明和下载链接

---

## 使用指南

### 配置 GitHub Container Registry

1. **启用 GitHub Packages**
   - 仓库设置 → Actions → General
   - 勾选 "Read and write permissions"

2. **首次推送后**
   - 访问 `https://github.com/{owner}/{repo}/pkgs/container/{repo}`
   - 将包设置为 Public (可选)

### 手动触发构建

1. 访问 Actions 页面
2. 选择 "Build and Push Docker Images"
3. 点击 "Run workflow"
4. 可选择构建特定发行版:
   - 输入 `ubuntu2404,debian12` 构建指定发行版
   - 留空或输入 `all` 构建所有发行版

### 创建新版本

```bash
# 1. 创建并推送标签
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 2. GitHub Actions 自动:
#    - 构建所有发行版镜像
#    - 推送到 ghcr.io
#    - 创建 GitHub Release
```

---

## 拉取镜像

### 自动选择架构 (推荐)

Docker 会自动选择与当前系统匹配的架构:

```bash
# 自动选择架构
docker pull ghcr.io/{owner}/{repo}:ubuntu2404-latest

# 运行容器
docker run -d \
  --name vgl-desktop \
  --device /dev/dri \
  -e VNC_PASSWORD=your_password \
  -p 5901:5901 \
  ghcr.io/{owner}/{repo}:ubuntu2404-latest
```

### 指定架构

```bash
# 强制使用 amd64 (x86_64)
docker pull --platform linux/amd64 ghcr.io/{owner}/{repo}:ubuntu2404-latest

# 强制使用 arm64 (aarch64)
docker pull --platform linux/arm64 ghcr.io/{owner}/{repo}:ubuntu2404-latest
```

### 查看支持的架构

```bash
# 查看镜像清单
docker manifest inspect ghcr.io/{owner}/{repo}:ubuntu2404-latest
```

### 私有镜像 (需要认证)

```bash
# 1. 创建 Personal Access Token (PAT)
#    Settings → Developer settings → Personal access tokens
#    权限: read:packages

# 2. 登录
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 3. 拉取镜像
docker pull ghcr.io/{owner}/{repo}:ubuntu2404-latest
```

---

## 本地测试工作流

使用 [act](https://github.com/nektos/act) 在本地测试 GitHub Actions:

```bash
# 安装 act
brew install act  # macOS
# 或
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# 测试构建工作流
act push -W .github/workflows/build-and-push.yml

# 测试特定 job
act -j build
```

---

## 构建矩阵说明

### 优先级分类

| 优先级 | 发行版 | 说明 |
|--------|--------|------|
| **high** | ubuntu2404, ubuntu2204, debian13, rocky9, alma9 | 推荐的生产环境发行版 |
| **medium** | fedora40 | 较新的技术栈 |
| **low** | debian12, rocky8, alma8, fedora39 | 旧版本或即将过期 |

### 并行构建

- 所有发行版并行构建,互不影响
- 使用 `fail-fast: false` 确保单个失败不影响其他构建
- 每个发行版独立缓存,加速后续构建

---

## 缓存策略

### GitHub Actions Cache

- 每个发行版独立缓存
- 缓存键: `type=gha,scope={distro}`
- 自动清理过期缓存

### 缓存大小优化

```yaml
cache-to: type=gha,mode=max,scope=${{ matrix.distro }}
```

- `mode=max`: 缓存所有层
- 加速后续构建 50-80%

---

## 故障排查

### 构建失败

1. **检查日志**
   ```bash
   # 访问 Actions 页面查看详细日志
   ```

2. **本地复现**
   ```bash
   docker build --build-arg BASE_DISTRO=ubuntu2404 .
   ```

3. **清除缓存**
   - Settings → Actions → Caches
   - 删除相关缓存后重新构建

### 推送失败

1. **检查权限**
   - Settings → Actions → General
   - 确保 "Read and write permissions" 已启用

2. **检查包可见性**
   - Packages 页面
   - 确保包设置正确

### 镜像拉取失败

1. **公开镜像**
   ```bash
   # 确保包已设置为 Public
   ```

2. **私有镜像**
   ```bash
   # 检查 PAT 权限
   # 重新登录
   docker logout ghcr.io
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

---

## 最佳实践

### 1. 版本管理

```bash
# 使用语义化版本
v1.0.0  # 主版本.次版本.修订号
v1.1.0  # 新功能
v1.1.1  # Bug 修复
```

### 2. 分支策略

- `main`: 稳定版本,自动构建和推送
- `develop`: 开发版本,仅构建不推送
- `feature/*`: 功能分支,PR 时测试

### 3. 标签策略

- `{distro}-latest`: 始终指向最新构建
- `{distro}-{version}`: 固定版本,不可变
- `{distro}-{sha}`: 特定提交,用于调试

### 4. 安全建议

- 定期更新基础镜像
- 使用 Dependabot 自动更新依赖
- 启用 GitHub Security Advisories

---

## 监控和通知

### Slack 通知 (可选)

在工作流中添加:

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Build ${{ matrix.distro }}: ${{ job.status }}'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

### Email 通知

- Settings → Notifications
- 启用 "Actions" 通知

---

## 相关资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [GitHub Container Registry 文档](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Docker Metadata Action](https://github.com/docker/metadata-action)
