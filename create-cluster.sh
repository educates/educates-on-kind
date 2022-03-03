#!/bin/bash

set -x

set -o errexit

# Read local settings overrides.

if [ -f local-settings.env ]; then
    . local-settings.env
fi

REGISTRY_NAME=${REGISTRY_NAME:-kind-registry}
REGISTRY_PORT=${REGISTRY_PORT:-5001}

SECURITY_POLICIES=${SECURITY_POLICIES:-true}
KAPP_CONTROLLER=${KAPP_CONTROLLER:-false}

# Create the image registry.

./create-registry.sh

# Create the kind cluster.

KUBEADM_CONFIG_PATCHES="  kubeadmConfigPatches: []"

if [ x"$SECURITY_POLICIES" != x"false" ]; then
    read -r -d '' KUBEADM_CONFIG_PATCHES <<EOF || true
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
EOF
else
    read -r -d '' KUBEADM_CONFIG_PATCHES <<EOF || true
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
EOF
fi

cat <<EOF | kind create cluster --name kind --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  ${KUBEADM_CONFIG_PATCHES}
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.eduk8s.svc.cluster.local:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:5000"]
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
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Create pod security polices and corresponding roles and bindings.

if [ x"$SECURITY_POLICIES" != x"false" ]; then
    kubectl apply -f policy-resources/privileged-psp.yaml
    kubectl apply -f policy-resources/baseline-psp.yaml
    kubectl apply -f policy-resources/restricted-psp.yaml

    kubectl apply -f policy-resources/cluster-roles.yaml
    kubectl apply -f policy-resources/role-bindings.yaml
fi

# Deploy kapp controller.

if [ x"$KAPP_CONTROLLER" != x"false" ]; then
    kapp deploy -a kc --yes -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
fi

# Deploy Contour ingress controller.

if [ x"$SECURITY_POLICIES" != x"false" ]; then
    kubectl create ns projectcontour
    kubectl apply -f contour-resources/role-binding.yaml
fi

kubectl apply -f https://projectcontour.io/quickstart/contour.yaml

kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'

kubectl rollout status deployment/contour -n projectcontour

kubectl rollout status daemonset/envoy -n projectcontour
