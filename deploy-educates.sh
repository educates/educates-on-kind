#!/bin/bash

set -x

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

EDUCATES_VERSION=${EDUCATES_VERSION:-master}
SOURCE_REPOSITORY=${SOURCE_REPOSITORY:-}

# Deploy Educates.

if [ x"$SOURCE_REPOSITORY" != x"" ]; then
    kubectl apply -k "$SOURCE_REPOSITORY"
else
    kubectl apply -k "github.com/eduk8s/eduk8s?ref=$EDUCATES_VERSION"
fi

# Wait for Educates operator to finish deploying.

kubectl rollout status deployment/eduk8s-operator -n eduk8s

# Apply system profiles for Educates.

kubectl apply -f educates-resources/default-system-profile.yaml

ENVIRON_VARIABLES=""

if [ x"$INGRESS_DOMAIN" != x"" ]; then
    ENVIRON_VARIABLES="INGRESS_DOMAIN=$INGRESS_DOMAIN"

    if [ -f "educates-resources/$INGRESS_DOMAIN-tls.yaml" ]; then
        kubectl apply -f educates-resources/$INGRESS_DOMAIN-tls.yaml -n eduk8s
        ENVIRON_VARIABLES="$ENVIRON_VARIABLES INGRESS_SECRET=$INGRESS_DOMAIN-tls"
    fi

    if [ -f "educates-resources/$INGRESS_DOMAIN-profile.yaml" ]; then
        kubectl apply -f educates-resources/$INGRESS_DOMAIN-profile.yaml
        ENVIRON_VARIABLES="$ENVIRON_VARIABLES SYSTEM_PROFILE=$INGRESS_DOMAIN-profile"
    fi
fi

if [ x"$ENVIRON_VARIABLES" != x"" ]; then
    kubectl set env deployment/eduk8s-operator -n eduk8s $ENVIRON_VARIABLES
fi
