#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

EDUCATES_VERSION=${EDUCATES_VERSION:-master}
SOURCE_REPOSITORY=${SOURCE_REPOSITORY:-}

# Delete Educates.

if [ x"$SOURCE_REPOSITORY" != x"" ]; then
    kubectl delete -k "$SOURCE_REPOSITORY"
else
    kubectl delete -k "github.com/eduk8s/eduk8s?ref=$EDUCATES_VERSION"
fi
