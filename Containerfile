FROM ghcr.io/containerpak/gtk-sdk:main AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends blueprint-compiler ca-certificates curl gettext python3 && \
    curl -fsSL https://gitlab.gnome.org/World/Upscaler/-/archive/c750d8a0f69865f49af6225e2828d373337633ce/Upscaler-c750d8a0f69865f49af6225e2828d373337633ce.tar.gz \
      -o /tmp/upscaler.tar.gz && \
    echo '4a6179d280ac951b13f3fcaeb1b4d39455780cd66a3ed2e4b5557f74ed95bb9e  /tmp/upscaler.tar.gz' | sha256sum -c - && \
    mkdir -p /tmp/upscaler && \
    tar -xzf /tmp/upscaler.tar.gz -C /tmp/upscaler --strip-components=1 && \
    meson setup /tmp/upscaler/build /tmp/upscaler --prefix=/usr && \
    DESTDIR=/opt/stage meson install -C /tmp/upscaler/build

FROM ghcr.io/containerpak/gtk:main

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl gir1.2-adw-1 gir1.2-gtk-4.0 libvulkan1 \
    python3-cffi python3-gi python3-pil python3-pip unzip && \
    curl -fsSL https://files.pythonhosted.org/packages/f7/e5/7b28a123d33fc9c3d55383628fc38322c890a97dfa2c538a7638cd71d57f/vulkan-1.3.275.1-py3-none-any.whl \
      -o /tmp/vulkan-1.3.275.1-py3-none-any.whl && \
    echo 'e1e0ddf57d3a7d19f79ebf1e192b20dbd378172b027cad4f495d961b51409586  /tmp/vulkan-1.3.275.1-py3-none-any.whl' | sha256sum -c - && \
    pip3 install --break-system-packages --no-deps /tmp/vulkan-1.3.275.1-py3-none-any.whl && \
    curl -fsSL https://github.com/upscayl/upscayl-ncnn/releases/download/20240601-103425/upscayl-bin-20240601-103425-linux.zip \
      -o /tmp/upscayl.zip && \
    echo '6dad58da39547d64753470ef5a24c4094ce1085b9cb81dabf7e44bd3b7a807a4  /tmp/upscayl.zip' | sha256sum -c - && \
    unzip -q /tmp/upscayl.zip -d /tmp/upscayl && \
    install -Dm755 /tmp/upscayl/upscayl-bin-20240601-103425-linux/upscayl-bin /usr/bin/upscayl-bin && \
    curl -fsSL https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip \
      -o /tmp/models.zip && \
    echo 'e5aa6eb131234b87c0c51f82b89390f5e3e642b7b70f2b9bbe95b6a285a40c96  /tmp/models.zip' | sha256sum -c - && \
    unzip -q /tmp/models.zip -d /tmp/models && \
    mkdir -p /usr/bin/models && \
    cp /tmp/models/models/*.bin /tmp/models/models/*.param /usr/bin/models/ && \
    cpak-clean-junk

COPY --from=build /opt/stage/usr /usr
