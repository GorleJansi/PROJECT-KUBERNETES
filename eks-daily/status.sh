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

echo "========================================"
echo "AWS identity"
echo "========================================"

aws sts get-caller-identity \
  --query '{Account:Account,User:Arn}' \
  --output table

echo
echo "========================================"
echo "EKS cluster"
echo "========================================"

aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}' \
  --output table

echo
echo "========================================"
echo "Managed Spot node group"
echo "========================================"

aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --region "$AWS_REGION" \
  --query 'nodegroup.{
    Name:nodegroupName,
    Status:status,
    Capacity:capacityType,
    InstanceTypes:instanceTypes,
    Min:scalingConfig.minSize,
    Desired:scalingConfig.desiredSize,
    Max:scalingConfig.maxSize
  }' \
  --output table

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  >/dev/null

echo
echo "========================================"
echo "Kubernetes nodes"
echo "========================================"

kubectl get nodes \
  -L eks.amazonaws.com/capacityType,node.kubernetes.io/instance-type \
  2>/dev/null || echo "No worker nodes are running."

echo
echo "========================================"
echo "Kubernetes system Pods"
echo "========================================"

kubectl get pods -n kube-system -o wide \
  2>/dev/null || echo "Pods unavailable because worker nodes are stopped."

echo
echo "========================================"
echo "Daily lab resources"
echo "========================================"

kubectl get all -n "$LAB_NAMESPACE" \
  2>/dev/null || echo "Daily lab namespace does not exist."
