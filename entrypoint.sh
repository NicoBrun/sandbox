#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*"
}

wait_for_docker() {
  local i
  for i in $(seq 1 90); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

start_dockerd() {
  if docker info >/dev/null 2>&1; then
    log "Docker daemon already running."
    return
  fi

  log "Starting dockerd..."

  dockerd \
    --host=unix:///var/run/docker.sock \
    --data-root=/var/lib/docker \
    --storage-driver=vfs \
    > /var/log/dockerd.log 2>&1 &

  wait_for_docker
}

run_tool_smoke() {
  git --version
  rg --version | head -1
  semgrep --version
  docker version
  docker buildx version
}

touch /ready

start_dockerd
run_tool_smoke

log "Sandbox ready."

tail -f /var/log/dockerd.log