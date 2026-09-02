#!/usr/bin/env bash
# Per-boot startup for Dify: bring up the Docker daemon and middleware stack,
# then apply database migrations. The API, worker, and web dev servers run as
# long-lived terminals (see environment.json).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
export PATH="$HOME/.local/bin:$PATH"

log() { printf '\n=== %s ===\n' "$*"; }

log "Starting Docker daemon"
if ! sudo docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid || true
  sudo setsid bash -c 'dockerd >/tmp/dockerd.log 2>&1' </dev/null &
  for _ in $(seq 1 60); do sudo docker info >/dev/null 2>&1 && break; sleep 1; done
fi
if ! sudo docker info >/dev/null 2>&1; then
  echo "Docker daemon failed to start:" >&2
  tail -n 40 /tmp/dockerd.log >&2 || true
  exit 1
fi

log "Granting docker group access to the socket"
sudo chown root:docker /var/run/docker.sock || true
sudo chmod 660 /var/run/docker.sock || true

log "Starting middleware stack (postgres, redis, sandbox, ssrf_proxy, plugin_daemon, weaviate)"
(cd docker && sudo docker compose -f docker-compose.middleware.yaml --profile weaviate -p dify up -d)

log "Waiting for PostgreSQL to become healthy"
for _ in $(seq 1 60); do
  if sudo docker exec dify-db-1 pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

log "Applying database migrations (idempotent)"
(cd api && uv run flask db upgrade)

log "Start complete: middleware is up and the database is migrated"
