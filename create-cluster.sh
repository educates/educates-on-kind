#!/bin/bash

set -x

set -o errexit

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

REGISTRY_NAME=${REGISTRY_NAME:-kind-registry}
REGISTRY_PORT=${REGISTRY_PORT:-5000}

# Create the image registry.

./create-registry.sh

# Create the kind cluster.

CONTAINERD_CONFIGD_PATCHES=""

if [ x"$INGRESS_DOMAIN" != x"" ]; then
    read -r -d '' CONTAINERD_CONFIGD_PATCHES <<EOF || true
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.$INGRESS_DOMAIN:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:${REGISTRY_PORT}"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:${REGISTRY_PORT}"]
EOF
else
    read -r -d '' CONTAINERD_CONFIGD_PATCHES <<EOF || true
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:${REGISTRY_PORT}"]
EOF
fi

cat <<EOF | kind create cluster --name kind --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  - |
    kind: ClusterConfiguration
    metadata:
      name: config
    apiServer:
      extraArgs:
        enable-admission-plugins: PodSecurityPolicy
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
$CONTAINERD_CONFIGD_PATCHES
EOF

# Connect the image registry to the cluster network.

docker network connect "kind" "${REGISTRY_NAME}" || true

# Document existence of the local registry.

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Create pod security polices and corresponding roles and bindings.

kubectl apply -f policy-resources/privileged-psp.yaml
kubectl apply -f policy-resources/baseline-psp.yaml
kubectl apply -f policy-resources/restricted-psp.yaml

kubectl apply -f policy-resources/cluster-roles.yaml
kubectl apply -f policy-resources/role-bindings.yaml

# Deploy Contour ingress controller.

kubectl create ns projectcontour

kubectl apply -f contour-resources/role-binding.yaml

kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'

kubectl rollout status deployment/contour -n projectcontour

kubectl rollout status daemonset/envoy -n projectcontour