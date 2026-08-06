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

echo "========================================"
echo "Terraform EKS setup"
echo "========================================"
echo
echo "Target:"
echo "  Cluster:   $CLUSTER_NAME"
echo "  Region:    $AWS_REGION"
echo "  Nodegroup: $NODEGROUP_NAME"
echo "  Nodes:     $DESIRED_NODES"
echo "  Node type: $NODE_TYPE"
echo
echo "This installs Terraform if needed and creates billable AWS resources."
read -r -p "Type TERRAFORM to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "TERRAFORM" ]]; then
    echo "Terraform setup cancelled."
    exit 0
fi

"$SCRIPT_DIR/install-aws-cli.sh"
"$SCRIPT_DIR/install-kubectl.sh"
"$SCRIPT_DIR/install-terraform.sh"

require_command aws
require_command terraform
require_command kubectl

echo
echo "AWS identity:"
aws sts get-caller-identity \
  --query '{Account:Account,User:Arn}' \
  --output table

cd "$SCRIPT_DIR/terraform"

echo
echo "Initializing Terraform..."
terraform init

echo
echo "Applying Terraform..."
terraform apply \
  -var "aws_region=$AWS_REGION" \
  -var "cluster_name=$CLUSTER_NAME" \
  -var "node_group_name=$NODEGROUP_NAME" \
  -var "node_desired_size=$DESIRED_NODES" \
  -var "node_max_size=$MAX_NODES" \
  -var "node_instance_type=$NODE_TYPE"

echo
echo "Updating kubeconfig..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "Checking nodes..."
kubectl get nodes \
  -L eks.amazonaws.com/capacityType,node.kubernetes.io/instance-type

echo
echo "========================================"
echo "TERRAFORM EKS CLUSTER READY"
echo "========================================"
echo
echo "Next commands:"
echo "  cd $SCRIPT_DIR"
echo "  ./status.sh"
echo "  ./practice.sh"
