#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $1"
        echo "Run: $SCRIPT_DIR/install-tools.sh"
        exit 1
    }
}

require_command aws
require_command eksctl
require_command kubectl
require_command awk

nodegroup_exists() {
    aws eks describe-nodegroup \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      >/dev/null 2>&1
}

wait_for_cluster() {
    echo "Waiting for cluster to become ACTIVE..."
    aws eks wait cluster-active \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION"
}

wait_for_nodegroup() {
    echo "Waiting for node group to become ACTIVE..."
    aws eks wait nodegroup-active \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION"
}

create_nodegroup() {
    eksctl create nodegroup \
      --cluster "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --name "$NODEGROUP_NAME" \
      --managed \
      --nodes "$DESIRED_NODES" \
      --nodes-min 0 \
      --nodes-max "$MAX_NODES" \
      --node-type "$NODE_TYPE"
}

echo "========================================"
echo "Creating EKS daily lab cluster"
echo "========================================"

echo
echo "AWS identity:"
aws sts get-caller-identity \
  --query '{Account:Account,User:Arn}' \
  --output table

echo
echo "Target:"
echo "  Cluster:   $CLUSTER_NAME"
echo "  Region:    $AWS_REGION"
echo "  Nodegroup: $NODEGROUP_NAME"
echo "  Nodes:     $DESIRED_NODES"
echo "  Node type: $NODE_TYPE"
echo
echo "Cost reminder: EKS control plane and EC2 worker nodes can create AWS charges."
read -r -p "Type CREATE to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "CREATE" ]]; then
    echo "Cluster creation cancelled."
    exit 0
fi

echo
echo "Checking if cluster already exists..."

if aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then
    CLUSTER_STATUS=$(aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --query 'cluster.status' \
      --output text)

    echo "Cluster already exists with status: $CLUSTER_STATUS"
else
    eksctl create cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --managed \
      --nodes "$DESIRED_NODES" \
      --nodes-min 0 \
      --nodes-max "$MAX_NODES" \
      --node-type "$NODE_TYPE" \
      --nodegroup-name "$NODEGROUP_NAME"
fi

echo
wait_for_cluster

echo
echo "Checking managed node group..."

if nodegroup_exists; then
    NODEGROUP_STATUS=$(aws eks describe-nodegroup \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      --query 'nodegroup.status' \
      --output text)

    echo "Node group already exists with status: $NODEGROUP_STATUS"

    if [[ "$NODEGROUP_STATUS" != "ACTIVE" ]]; then
        wait_for_nodegroup
    fi
else
    echo "Node group not found. Creating node group: $NODEGROUP_NAME"
    create_nodegroup
    wait_for_nodegroup
fi

CURRENT_DESIRED=$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.scalingConfig.desiredSize' \
  --output text)

if [[ "$CURRENT_DESIRED" != "$DESIRED_NODES" ]]; then
    echo "Scaling node group from $CURRENT_DESIRED to $DESIRED_NODES nodes..."
    aws eks update-nodegroup-config \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      --scaling-config minSize=0,maxSize="$MAX_NODES",desiredSize="$DESIRED_NODES" \
      --query 'update.{ID:id,Status:status}' \
      --output table
    wait_for_nodegroup
fi

echo
echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "Node groups:"
eksctl get nodegroup \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "Checking Kubernetes nodes..."
for _ in $(seq 1 40); do
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null |
        awk '$2 == "Ready" {count++} END {print count+0}')

    echo "Ready nodes: $READY_NODES/$DESIRED_NODES"

    if [[ "$READY_NODES" -ge "$DESIRED_NODES" ]]; then
        break
    fi

    sleep 30
done

kubectl get nodes \
  -L eks.amazonaws.com/capacityType,node.kubernetes.io/instance-type

echo
echo "========================================"
echo "EKS CLUSTER SETUP COMPLETE"
echo "========================================"
echo
echo "Next commands:"
echo "  $SCRIPT_DIR/status.sh"
echo "  $SCRIPT_DIR/practice.sh"
