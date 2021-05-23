#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

REGISTRY_NAME=${REGISTRY_NAME:-kind-registry}
REGISTRY_HOST=${REGISTRY_HOST:-127.0.0.1}
REGISTRY_PORT=${REGISTRY_PORT:-5000}

# Create the image registry unless it already exists.

running="$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)"

if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${REGISTRY_HOST}:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" \
    registry:2
fi
