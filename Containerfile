FROM ghcr.io/containerpak/gtk4-sdk:main AS build

ARG DEBIAN_FRONTEND=noninteractive

ADD --checksum=sha256:4a6179d280ac951b13f3fcaeb1b4d39455780cd66a3ed2e4b5557f74ed95bb9e https://gitlab.gnome.org/World/Upscaler/-/archive/c750d8a0f69865f49af6225e2828d373337633ce/Upscaler-c750d8a0f69865f49af6225e2828d373337633ce.tar.gz /tmp/upscaler.tar.gz

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    blueprint-compiler desktop-file-utils gettext libglib2.0-bin python3 && \
    mkdir -p /tmp/upscaler && \
    tar -xzf /tmp/upscaler.tar.gz -C /tmp/upscaler --strip-components=1 && \
    meson setup /tmp/upscaler/build /tmp/upscaler --prefix=/usr && \
    DESTDIR=/opt/stage meson install -C /tmp/upscaler/build

FROM ubuntu:26.04 AS vulkan

ADD --checksum=sha256:e1e0ddf57d3a7d19f79ebf1e192b20dbd378172b027cad4f495d961b51409586 https://files.pythonhosted.org/packages/f7/e5/7b28a123d33fc9c3d55383628fc38322c890a97dfa2c538a7638cd71d57f/vulkan-1.3.275.1-py3-none-any.whl /tmp/vulkan-1.3.275.1-py3-none-any.whl

FROM ubuntu:26.04 AS upscayl

ADD --checksum=sha256:6dad58da39547d64753470ef5a24c4094ce1085b9cb81dabf7e44bd3b7a807a4 https://github.com/upscayl/upscayl-ncnn/releases/download/20240601-103425/upscayl-bin-20240601-103425-linux.zip /tmp/upscayl.zip

RUN apt-get update && \
    apt-get install -y --no-install-recommends unzip && \
    unzip -q /tmp/upscayl.zip -d /tmp/upscayl && \
    install -Dm755 /tmp/upscayl/upscayl-bin-20240601-103425-linux/upscayl-bin /out/upscayl-bin

FROM ubuntu:26.04 AS models

ADD --checksum=sha256:e5aa6eb131234b87c0c51f82b89390f5e3e642b7b70f2b9bbe95b6a285a40c96 https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip /tmp/models.zip

RUN apt-get update && \
    apt-get install -y --no-install-recommends unzip && \
    unzip -q /tmp/models.zip -d /tmp/models && \
    mkdir -p /out && \
    cp /tmp/models/models/*.bin /tmp/models/models/*.param /out/

FROM ghcr.io/containerpak/adwaita:main

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=build /opt/stage/usr /usr
COPY --from=upscayl /out/upscayl-bin /usr/bin/upscayl-bin
COPY --from=models /out/ /usr/bin/models/

RUN --mount=type=bind,from=vulkan,source=/tmp/vulkan-1.3.275.1-py3-none-any.whl,target=/run/vulkan-1.3.275.1-py3-none-any.whl \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    gir1.2-adw-1 gir1.2-gtk-4.0 libvulkan1 libglib2.0-bin \
    python3-cffi python3-gi python3-pil python3-pip && \
    pip3 install --break-system-packages --no-deps /run/vulkan-1.3.275.1-py3-none-any.whl && \
    glib-compile-schemas /usr/share/glib-2.0/schemas && \
    cpak-clean-junk
