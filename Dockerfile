FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DOCKER_BUILDKIT=1

# Go
ARG GO_VERSION=1.27.1

# Make Go and globally installed binaries available everywhere
ENV PATH="/usr/local/go/bin:/usr/local/bin:/root/.pdtm/go/bin:${PATH}"

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

# Install Go
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
    go version

# Install ProjectDiscovery Tool Manager (pdtm)
#
# GOBIN=/usr/local/bin makes pdtm itself globally available.
RUN GOBIN=/usr/local/bin \
    go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest \
 && pdtm -version

# Install all ProjectDiscovery tools globally.
#
# By default pdtm would use:
#   $HOME/.pdtm/go/bin
#run pdtm -install-all -binary-path "$HOME/.pdtm/go/bin" -no-color
RUN pdtm -install-all -bp /usr/local/bin -no-color

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
