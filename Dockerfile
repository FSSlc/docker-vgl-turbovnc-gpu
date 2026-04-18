# syntax=docker/dockerfile:1.7

ARG BASE_DISTRO=ubuntu2404
ARG TURBOVNC_VERSION=3.3.1
ARG VIRTUALGL_VERSION=3.1.4
ARG NOVNC_VERSION=1.5.0

FROM alpine:3.20 AS downloader
ARG TURBOVNC_VERSION
ARG VIRTUALGL_VERSION
ARG NOVNC_VERSION
RUN apk add --no-cache curl tar
RUN mkdir -p /out/deb /out/rpm /out/noVNC
RUN curl -fsSL "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" \
    -o "/out/deb/virtualgl_${VIRTUALGL_VERSION}_amd64.deb" \
 && curl -fsSL "https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VERSION}/VirtualGL-${VIRTUALGL_VERSION}.x86_64.rpm" \
    -o "/out/rpm/VirtualGL-${VIRTUALGL_VERSION}.x86_64.rpm" \
 && curl -fsSL "https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb" \
    -o "/out/deb/turbovnc_${TURBOVNC_VERSION}_amd64.deb" \
 && curl -fsSL "https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VERSION}/turbovnc-${TURBOVNC_VERSION}.x86_64.rpm" \
    -o "/out/rpm/turbovnc-${TURBOVNC_VERSION}.x86_64.rpm" \
 && curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
    -o /tmp/noVNC.tar.gz \
 && tar -xzf /tmp/noVNC.tar.gz -C /out/noVNC --strip-components=1 \
 && rm -f /tmp/noVNC.tar.gz

FROM downloader AS artifacts

FROM ubuntu:24.04 AS base-ubuntu2404
FROM ubuntu:22.04 AS base-ubuntu2204
FROM debian:12 AS base-debian12
FROM rockylinux:9 AS base-rocky9

ARG BASE_DISTRO
FROM base-${BASE_DISTRO} AS runtime

ARG TURBOVNC_VERSION
ARG VIRTUALGL_VERSION

ENV HOME=/root \
    USER=root \
    LOGNAME=root \
    SHELL=/bin/bash \
    VNC_DISPLAY=:1 \
    VNC_GEOMETRY=1920x1080 \
    VNC_DEPTH=24 \
    VNC_PASSWORD=root \
    VNC_RESET_PASSWORD=1 \
    VNC_NOVNC_DIR=/opt/noVNC \
    VNC_EXTRA_ARGS= \
    VGL_DISPLAY=egl0 \
    VGL_COMPRESS=proxy \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    PATH=/opt/TurboVNC/bin:/opt/VirtualGL/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY --from=artifacts /out /tmp/artifacts
COPY docker /opt/container

RUN chmod +x /opt/container/*.sh \
 && TURBOVNC_VERSION="${TURBOVNC_VERSION}" \
    VIRTUALGL_VERSION="${VIRTUALGL_VERSION}" \
    /opt/container/install-runtime.sh \
 && rm -rf /tmp/artifacts

WORKDIR /root
EXPOSE 5801 5901

ENTRYPOINT ["/opt/container/entrypoint.sh"]
CMD ["start"]
