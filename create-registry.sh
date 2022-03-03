#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

REGISTRY_NAME=${REGISTRY_NAME:-kind-registry}
REGISTRY_HOST=${REGISTRY_HOST:-127.0.0.1}

# Create the image registry unless it already exists.

running="$(docker inspect -f "{{.State.Running}}" "${REGISTRY_NAME}" 2>/dev/null || true)"

if [ "${running}" = "true" ]; then
    exit 0
fi

REGISTRY_PORT=${REGISTRY_PORT:-5001}

REGISTRY_ARGS="-v `pwd`/educates-resources:/files"

if [ -f "educates-resources/htpasswd" ]; then
    REGISTRY_HTPASSWD=htpasswd
fi

if [ -f "educates-resources/$INGRESS_DOMAIN.htpasswd" ]; then
    REGISTRY_HTPASSWD=$INGRESS_DOMAIN.htpasswd
fi

if [ x"$REGISTRY_HTPASSWD" != x"" ]; then
    REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH=htpasswd"
    REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH_HTPASSWD_REALM=Educates"
    REGISTRY_ARGS="$REGISTRY_ARGS -e REGISTRY_AUTH_HTPASSWD_PATH=/files/$REGISTRY_HTPASSWD"
fi

docker run -d --restart=always ${REGISTRY_ARGS} \
    -p "${REGISTRY_HOST}:${REGISTRY_PORT}:5000" \
    --name "${REGISTRY_NAME}" registry:2
