#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

command -v kubectl >/dev/null 2>&1 || {
    echo "ERROR: required command not found: kubectl"
    exit 1
}

echo "Deleting namespace: $LAB_NAMESPACE"

kubectl delete namespace "$LAB_NAMESPACE" \
  --ignore-not-found=true \
  --wait=true

echo "Daily practice resources deleted."
