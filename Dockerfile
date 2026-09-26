FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Versions
# ---------------------------------------------------------------------------

ARG GO_VERSION=1.27.1

# ---------------------------------------------------------------------------
# Base tooling
# ---------------------------------------------------------------------------

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
    nmap \
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

# ---------------------------------------------------------------------------
# Sandbox user
# ---------------------------------------------------------------------------

RUN groupadd \
      --gid 10001 \
      sandbox \
 && useradd \
      --uid 10001 \
      --gid 10001 \
      --create-home \
      --home-dir /home/sandbox \
      --shell /bin/bash \
      sandbox

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
        amd64) \
            goarch="amd64"; \
            sha256="63d339f0da5ab53635a56f2490a7984dfe12dfcff22ad749f63edaf590168445"; \
            ;; \
        arm64) \
            goarch="arm64"; \
            sha256="3450b45a3f9ee8568792736a5c5e70a1f2e9b36c35a8f74958c03e51d7d92bec"; \
            ;; \
        *) \
            echo "Unsupported architecture: ${arch}"; \
            exit 1; \
            ;; \
    esac; \
    curl -fsSL \
        "https://go.dev/dl/go${GO_VERSION}.linux-${goarch}.tar.gz" \
        -o /tmp/go.tar.gz; \
    echo "${sha256}  /tmp/go.tar.gz" | sha256sum -c -; \
    rm -rf /usr/local/go; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    rm -f /tmp/go.tar.gz; \
    /usr/local/go/bin/go version

ENV PATH="/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin"

# ---------------------------------------------------------------------------
# ProjectDiscovery Tool Manager
# ---------------------------------------------------------------------------

# pdtm itself is globally available.
RUN GOBIN=/usr/local/bin \
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest \
 && pdtm -version

# Install the PD tools as the sandbox user.
#
# They will end up under:
#
#   /home/sandbox/.pdtm/go/bin
#
USER sandbox

ENV HOME=/home/sandbox

RUN pdtm -install-all -no-color

USER root

# ---------------------------------------------------------------------------
# Semgrep
# ---------------------------------------------------------------------------

RUN python3 -m venv /opt/semgrep \
 && /opt/semgrep/bin/python -m pip install --upgrade pip wheel \
 && /opt/semgrep/bin/python -m pip install --no-cache-dir semgrep \
 && ln -sf /opt/semgrep/bin/semgrep /usr/local/bin/semgrep

# ---------------------------------------------------------------------------
# Docker Engine + Buildx
# ---------------------------------------------------------------------------

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

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Runtime directories
# ---------------------------------------------------------------------------

RUN mkdir -p \
      /workspace \
      /workspace/.config \
      /workspace/.cache \
      /workspace/tmp \
      /scratch \
      /var/lib/docker \
      /var/log \
 && chown -R sandbox:sandbox \
      /workspace \
      /scratch \
      /home/sandbox

# ---------------------------------------------------------------------------
# Runtime environment
# ---------------------------------------------------------------------------

ENV HOME=/home/sandbox
ENV XDG_CONFIG_HOME=/workspace/.config
ENV XDG_CACHE_HOME=/workspace/.cache
ENV TMPDIR=/workspace/tmp

ENV PATH="/home/sandbox/.pdtm/go/bin:/workspace/.local/bin:/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin"

WORKDIR /workspace

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

COPY entrypoint.sh /entrypoint.sh

RUN chmod 0755 /entrypoint.sh

# IMPORTANT:
# dockerd is intentionally rootful inside the Kata VM.
USER root

ENTRYPOINT ["/entrypoint.sh"]
