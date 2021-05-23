#!/bin/bash

set -x

# Delete the Kind cluster.

kind delete cluster --name kind
