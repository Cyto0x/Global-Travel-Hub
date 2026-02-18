#!/bin/sh
set -eu

: "${GTH_APP_PASSWORD:?GTH_APP_PASSWORD is required}"
: "${GTH_READONLY_PASSWORD:?GTH_READONLY_PASSWORD is required}"
: "${GTH_ADMIN_PASSWORD:?GTH_ADMIN_PASSWORD is required}"

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v gth_app_password="$GTH_APP_PASSWORD" \
  -v gth_readonly_password="$GTH_READONLY_PASSWORD" \
  -v gth_admin_password="$GTH_ADMIN_PASSWORD" \
  -f /docker-entrypoint-initdb.d/security.sql.tmpl
