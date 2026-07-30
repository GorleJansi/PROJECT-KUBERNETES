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
require_command kubectl
require_command awk

echo "========================================"
echo "Starting EKS daily lab"
echo "========================================"

echo
echo "Checking AWS identity..."
aws sts get-caller-identity \
  --query '{Account:Account,User:Arn}' \
  --output table

echo
echo "Checking EKS control plane..."

CLUSTER_STATUS=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'cluster.status' \
  --output text)

if [[ "$CLUSTER_STATUS" != "ACTIVE" ]]; then
    echo "ERROR: Cluster status is $CLUSTER_STATUS"
    exit 1
fi

echo "Cluster is ACTIVE."

echo
echo "Checking node group..."

NODEGROUP_STATUS=$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.status' \
  --output text)

if [[ "$NODEGROUP_STATUS" == "UPDATING" ]]; then
    echo "A previous node-group update is still running."
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

if [[ "$CURRENT_DESIRED" == "$DESIRED_NODES" ]]; then
    echo "Worker nodes are already configured for $DESIRED_NODES nodes."
else
    echo "Scaling node group from $CURRENT_DESIRED to $DESIRED_NODES nodes..."

    aws eks update-nodegroup-config \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      --scaling-config minSize=0,maxSize="$MAX_NODES",desiredSize="$DESIRED_NODES" \
      --query 'update.{ID:id,Status:status}' \
      --output table

    aws eks wait nodegroup-active \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION"
fi

echo
echo "Updating kubeconfig..."

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "Waiting for $DESIRED_NODES Kubernetes nodes to become Ready..."

for _ in $(seq 1 40); do
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null |
        awk '$2 == "Ready" {count++} END {print count+0}')

    echo "Ready nodes: $READY_NODES/$DESIRED_NODES"

    if [[ "$READY_NODES" -ge "$DESIRED_NODES" ]]; then
        break
    fi

    sleep 30
done

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null |
    awk '$2 == "Ready" {count++} END {print count+0}')

if [[ "$READY_NODES" -lt "$DESIRED_NODES" ]]; then
    echo
    echo "ERROR: Nodes did not become Ready."
    echo "Run: $SCRIPT_DIR/status.sh"
    exit 1
fi

echo
echo "========================================"
echo "EKS LAB IS READY"
echo "========================================"

kubectl get nodes \
  -L eks.amazonaws.com/capacityType,node.kubernetes.io/instance-type

echo
echo "Run daily practice with:"
echo "  $SCRIPT_DIR/practice.sh"
