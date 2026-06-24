#!/usr/bin/env bash

set -euo pipefail

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$WORKDIR/.env}"
IMAGE_NAME="${IMAGE_NAME:-qdrant/qdrant-local}"
CONTAINER_NAME="${CONTAINER_NAME:-qdrant-local}"
HTTP_PORT="${HTTP_PORT:-6333}"
GRPC_PORT="${GRPC_PORT:-6334}"
DATA_DIR="${DATA_DIR:-$WORKDIR/.docker/qdrant/storage}"
SNAPSHOTS_DIR="${SNAPSHOTS_DIR:-$WORKDIR/.docker/qdrant/snapshots}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing env file: $ENV_FILE" >&2
    echo "Create it from .env.example before running this script." >&2
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "Missing required env: $name" >&2
        exit 1
    fi
}

require_env "QDRANT_API_KEY"
require_env "QDRANT_READ_ONLY_API_KEY"
require_env "QDRANT_JWT_RBAC"

mkdir -p "$DATA_DIR" "$SNAPSHOTS_DIR"

if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Removing existing container: $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME" >/dev/null
fi

echo "Building image: $IMAGE_NAME"
docker build . --tag "$IMAGE_NAME"

echo "Starting container: $CONTAINER_NAME"
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$HTTP_PORT:6333" \
    -p "$GRPC_PORT:6334" \
    -v "$DATA_DIR:/qdrant/storage" \
    -v "$SNAPSHOTS_DIR:/qdrant/snapshots" \
    -e QDRANT__SERVICE__API_KEY="$QDRANT_API_KEY" \
    -e QDRANT__SERVICE__READ_ONLY_API_KEY="$QDRANT_READ_ONLY_API_KEY" \
    -e QDRANT__SERVICE__JWT_RBAC="$QDRANT_JWT_RBAC" \
    "$IMAGE_NAME"

echo "Qdrant is starting on http://localhost:$HTTP_PORT"
echo "Container: $CONTAINER_NAME"
