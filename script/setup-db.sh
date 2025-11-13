#!/usr/bin/env bash
set -euo pipefail

# Creates the Postgres database 'easy-count' on localhost:5438 if it doesn't exist.
# It uses Docker Compose's 'db' service and works even if psql is not installed on the host.

PROJECT_ROOT="$(cd "$(dirname "$0")"/.. && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
SERVICE_NAME="db"
CONTAINER_NAME="easy-count-db"
DB_NAME="easy-count"
DB_USER="postgres"
DB_PASSWORD="pass123"
DB_PORT_HOST=5438

# Detect docker compose command
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
  else
    echo "ERROR: docker compose (v2) or docker-compose (v1) is required." >&2
    exit 1
  fi
else
  echo "ERROR: Docker is not installed or not in PATH." >&2
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "ERROR: docker-compose.yml not found at $COMPOSE_FILE" >&2
  exit 1
fi

cd "$PROJECT_ROOT"

# Ensure the DB service is up
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Starting Postgres service '${SERVICE_NAME}'..."
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d "$SERVICE_NAME"
else
  echo "Postgres container '${CONTAINER_NAME}' already running."
fi

# Wait for Postgres to become healthy/ready
echo "Waiting for Postgres to become ready..."
ATTEMPTS=0
until docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS+1))
  if [ $ATTEMPTS -gt 60 ]; then
    echo "ERROR: Postgres did not become ready in time." >&2
    exit 1
  fi
  sleep 2
done

echo "Postgres is ready. Checking for database '$DB_NAME'..."

# Use psql inside the container to avoid host dependency
EXISTS=$(docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
  psql -U "$DB_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" || echo "")

if [ "$EXISTS" = "1" ]; then
  echo "Database '$DB_NAME' already exists. Nothing to do."
else
  echo "Creating database '$DB_NAME'..."
  docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
    psql -U "$DB_USER" -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
  echo "Database '$DB_NAME' created successfully."
fi

# Optional connectivity check from host via mapped port
echo "Verifying TCP connectivity on localhost:${DB_PORT_HOST}..."
if nc -z localhost "$DB_PORT_HOST" 2>/dev/null; then
  echo "Port ${DB_PORT_HOST} is reachable. Setup complete."
else
  echo "WARNING: Port ${DB_PORT_HOST} not reachable from host. Check Docker port mapping." >&2
fi
