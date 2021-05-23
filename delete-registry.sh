#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

REGISTRY_NAME=${REGISTRY_NAME:-kind-registry}

# Stop the image registry.

docker stop "${REGISTRY_NAME}"

# Delete the registry container.

docker rm "${REGISTRY_NAME}"
