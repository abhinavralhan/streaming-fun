#!/usr/bin/env bash
set -euo pipefail

SOURCE="host=postgres port=5432 dbname=postgres user=postgres password=${POSTGRES_PASSWORD:-secret}"
WAREHOUSE="host=warehouse port=5432 dbname=warehouse user=postgres password=${POSTGRES_PASSWORD:-secret}"

echo "[init] waiting for source + warehouse..."
until pg_isready -h postgres  -U postgres >/dev/null 2>&1; do sleep 1; done
until pg_isready -h warehouse -U postgres >/dev/null 2>&1; do sleep 1; done

echo "[init] ensuring metabase app database exists..."
psql "$WAREHOUSE" -tAc "select 1 from pg_database where datname='metabase'" | grep -q 1 \
  || psql "$WAREHOUSE" -c "CREATE DATABASE metabase;"

echo "[init] publication on source (idempotent)..."

if [ "$(psql "$SOURCE" -tAc "select 1 from pg_publication where pubname='analytics_pub'")" != "1" ]; then
  psql "$SOURCE" -c "CREATE PUBLICATION analytics_pub FOR ALL TABLES;"
else
  echo "[init]   already exists, skipping."
fi

echo "[init] warehouse tables + indexes (idempotent)..."
psql "$WAREHOUSE" -f /init/schema.sql

echo "[init] subscription on warehouse (idempotent)..."
if [ "$(psql "$WAREHOUSE" -tAc "select 1 from pg_subscription where subname='analytics_sub'")" != "1" ]; then
  psql "$WAREHOUSE" -c "CREATE SUBSCRIPTION analytics_sub CONNECTION '$SOURCE' PUBLICATION analytics_pub;"
  echo "[init]   subscription created — replication live."
else
  echo "[init]   already exists, skipping."
fi


echo "[init] refreshing planner stats..."
psql "$WAREHOUSE" -c "ANALYZE;" || true

echo "[init] done."