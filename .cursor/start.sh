#!/usr/bin/env bash
# Per-boot startup for Dify: bring up the Docker daemon and middleware stack,
# then apply database migrations. The API, worker, and web dev servers run as
# long-lived terminals (see environment.json).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
export PATH="$HOME/.local/bin:$PATH"

log() { printf '\n=== %s ===\n' "$*"; }

# Use a root-owned log path. A snapshot may persist /tmp/dockerd.log owned by
# a non-root user, and this VM blocks even root (via sudo) from writing to
# files owned by another user, which would break the log redirect below.
DOCKERD_LOG=/var/log/dify-dockerd.log

log "Starting Docker daemon"
if ! sudo docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid /tmp/dockerd.log || true
  sudo setsid bash -c "dockerd >'$DOCKERD_LOG' 2>&1" </dev/null &
  for _ in $(seq 1 60); do sudo docker info >/dev/null 2>&1 && break; sleep 1; done
fi
if ! sudo docker info >/dev/null 2>&1; then
  echo "Docker daemon failed to start:" >&2
  sudo tail -n 40 "$DOCKERD_LOG" >&2 || true
  exit 1
fi

log "Granting docker group access to the socket"
sudo chown root:docker /var/run/docker.sock || true
sudo chmod 660 /var/run/docker.sock || true

# In the nested Cloud Agent VM, bridged traffic filtered through iptables is
# dropped, which breaks container-to-container connectivity (e.g. the plugin
# daemon reaching Postgres). Disable bridge netfilter so same-network
# containers communicate directly at layer 2.
log "Disabling bridge netfilter for container-to-container connectivity"
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1 || true

log "Starting middleware stack (postgres, redis, sandbox, ssrf_proxy, plugin_daemon, weaviate)"
(cd docker && sudo docker compose -f docker-compose.middleware.yaml --profile weaviate -p dify up -d --remove-orphans)

# The sandbox initializes its runtime (e.g. its Node.js project) into its own
# writable container layer. A layer captured in a snapshot can crash-loop on a
# later boot, so recreate the sandbox from a fresh layer. Named volumes (e.g.
# the Postgres data dir) are preserved across recreation.
log "Recreating sandbox with a fresh layer"
(cd docker && sudo docker compose -f docker-compose.middleware.yaml --profile weaviate -p dify up -d --force-recreate --no-deps sandbox)

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
