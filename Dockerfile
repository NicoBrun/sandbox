FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER_BUILDKIT=1

# Base tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    coreutils \
    curl \
    file \
    findutils \
    gawk \
    git \
    gnupg \
    grep \
    gzip \
    iproute2 \
    iptables \
    jq \
    make \
    openssh-client \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    sed \
    tar \
    unzip \
    xz-utils \
    zip \
 && rm -rf /var/lib/apt/lists/*

# Install semgrep
RUN python3 -m venv /opt/semgrep \
 && /opt/semgrep/bin/python -m pip install --upgrade pip wheel \
 && /opt/semgrep/bin/python -m pip install --no-cache-dir semgrep \
 && ln -sf /opt/semgrep/bin/semgrep /usr/local/bin/semgrep

# Install Docker Engine + Buildx
RUN install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc

RUN . /etc/os-release \
 && arch="$(dpkg --print-architecture)" \
 && echo "Types: deb\n\
URIs: https://download.docker.com/linux/ubuntu\n\
Suites: ${UBUNTU_CODENAME}\n\
Components: stable\n\
Architectures: ${arch}\n\
Signed-By: /etc/apt/keyrings/docker.asc" \
 > /etc/apt/sources.list.d/docker.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

# Workspace
RUN mkdir -p /workspace /scratch

# Runtime entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]