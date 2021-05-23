#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

EDUCATES_VERSION=${EDUCATES_VERSION:-master}

# Delete Educates.

kubectl delete -k "github.com/eduk8s/eduk8s?ref=${EDUCATES_VERSION}"
