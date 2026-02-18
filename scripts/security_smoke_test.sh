#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/4] Checking containers are up..."
docker compose ps >/dev/null

echo "[2/4] Running PostgreSQL security verification..."
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 \
  -U "${POSTGRES_USER:-gth_user}" \
  -d "${POSTGRES_DB:-global_travel_hub}" \
  -f - < security_verification.sql >/tmp/gth_security_verification.out
echo "  OK: PostgreSQL verification passed"

echo "[3/4] Checking Redis auth enforcement..."
REDIS_OUT="$(docker compose exec -T redis sh -lc 'redis-cli ping 2>&1 || true')"
echo "$REDIS_OUT" | grep -q "NOAUTH Authentication required."
docker compose exec -T redis sh -lc 'redis-cli -a "$REDIS_PASSWORD" ping' | grep -q "PONG"
echo "  OK: Redis blocks unauthenticated access and allows authenticated access"

echo "[4/4] Checking PgBouncer least-privilege connectivity..."
docker compose exec -T postgres sh -lc \
  'PGPASSWORD="$GTH_APP_PASSWORD" psql -h pgbouncer -p 5432 -U gth_app -d "${POSTGRES_DB:-global_travel_hub}" -c "select current_user;"' \
  | grep -q "gth_app"
echo "  OK: PgBouncer routes with gth_app"

echo
echo "Security smoke test passed."
