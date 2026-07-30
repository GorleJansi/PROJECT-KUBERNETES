#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $1"
        exit 1
    }
}

require_command aws

echo "========================================"
echo "Stopping EKS worker nodes"
echo "========================================"

echo
echo "Deleting daily lab resources..."

if command -v kubectl >/dev/null 2>&1; then
    kubectl delete namespace "$LAB_NAMESPACE" \
      --ignore-not-found=true \
      --wait=false \
      2>/dev/null || true
else
    echo "kubectl not found, skipping Kubernetes namespace cleanup."
fi

NODEGROUP_STATUS=$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.status' \
  --output text)

if [[ "$NODEGROUP_STATUS" == "UPDATING" ]]; then
    echo "Waiting for the previous node-group update to complete..."

    aws eks wait nodegroup-active \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION"
fi

CURRENT_DESIRED=$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.scalingConfig.desiredSize' \
  --output text)

if [[ "$CURRENT_DESIRED" == "0" ]]; then
    echo "Worker nodes are already stopped."
    exit 0
fi

echo "Scaling worker-node count from $CURRENT_DESIRED to 0..."

aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --scaling-config minSize=0,maxSize="$MAX_NODES",desiredSize=0 \
  --query 'update.{ID:id,Status:status}' \
  --output table

aws eks wait nodegroup-active \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION"

echo
echo "========================================"
echo "WORKER NODES STOPPED"
echo "========================================"

aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.scalingConfig' \
  --output table

echo
echo "The EKS control plane still exists."
echo "Run start.sh when you want to practise again."
