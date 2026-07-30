#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

command -v eksctl >/dev/null 2>&1 || {
    echo "ERROR: required command not found: eksctl"
    exit 1
}

echo "WARNING"
echo "This permanently deletes:"
echo "  Cluster:   $CLUSTER_NAME"
echo "  Nodegroup: $NODEGROUP_NAME"
echo "  Region:    $AWS_REGION"
echo
read -r -p "Type DELETE to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "DELETE" ]]; then
    echo "Deletion cancelled."
    exit 0
fi

eksctl delete cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --wait

echo "EKS cluster deleted."
