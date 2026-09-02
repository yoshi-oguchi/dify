#!/usr/bin/env bash
# Idempotent Cloud Agent install for Dify.
# Installs toolchains (uv, Docker + fuse-overlayfs), prepares .env files,
# and installs backend (uv) and frontend (pnpm) dependencies. Long-running
# services (middleware, API, worker, web) are handled by start.sh / terminals.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { printf '\n=== %s ===\n' "$*"; }

log "Ensuring uv is installed"
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
uv --version

log "Ensuring Docker engine is installed"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
fi

log "Ensuring fuse-overlayfs is installed (overlayfs mounts fail in the nested VM)"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  -o Dpkg::Options::=--force-confold fuse-overlayfs fuse3

log "Configuring Docker daemon to use the fuse-overlayfs storage driver"
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "storage-driver": "fuse-overlayfs",
  "features": { "containerd-snapshotter": false }
}
JSON
sudo groupadd -f docker
sudo usermod -aG docker "$USER" || true

log "Preparing environment files"
if [ ! -f api/.env ]; then
  cp api/.env.example api/.env
  sed -i "/^SECRET_KEY=/c\\SECRET_KEY=$(openssl rand -base64 42)" api/.env
fi
[ -f web/.env.local ] || cp web/.env.example web/.env.local
[ -f docker/middleware.env ] || cp docker/middleware.env.example docker/middleware.env

log "Installing backend dependencies (uv sync --dev)"
(cd api && uv sync --dev)

log "Installing frontend dependencies (pnpm install)"
(cd web && pnpm install --frozen-lockfile)

log "Pre-pulling middleware images (best effort, speeds up first boot)"
if ! sudo docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid || true
  sudo setsid bash -c 'dockerd >/tmp/dockerd-install.log 2>&1' </dev/null &
  for _ in $(seq 1 60); do sudo docker info >/dev/null 2>&1 && break; sleep 1; done
  STARTED_DOCKER=1
fi
if sudo docker info >/dev/null 2>&1; then
  (cd docker && sudo docker compose -f docker-compose.middleware.yaml --profile weaviate -p dify pull) || true
fi
if [ "${STARTED_DOCKER:-0}" = "1" ]; then
  sudo pkill -TERM dockerd 2>/dev/null || true
  sleep 3
fi

log "Install complete"
