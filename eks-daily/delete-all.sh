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

require_command terraform

TERRAFORM_DIR="$SCRIPT_DIR/terraform"

if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo "ERROR: Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

echo "WARNING"
echo "This permanently destroys Terraform-managed EKS lab resources:"
echo "  Cluster:   $CLUSTER_NAME"
echo "  Nodegroup: $NODEGROUP_NAME"
echo "  Region:    $AWS_REGION"
echo
echo "Run this from the same checkout where Terraform apply created the cluster,"
echo "or configure a remote backend before relying on another workstation."
echo
read -r -p "Type DESTROY to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "DESTROY" ]]; then
    echo "Destroy cancelled."
    exit 0
fi

cd "$TERRAFORM_DIR"

terraform init
terraform destroy \
  -var "aws_region=$AWS_REGION" \
  -var "cluster_name=$CLUSTER_NAME" \
  -var "node_group_name=$NODEGROUP_NAME" \
  -var "node_desired_size=$DESIRED_NODES" \
  -var "node_max_size=$MAX_NODES" \
  -var "node_instance_type=$NODE_TYPE"

echo "Terraform-managed EKS lab resources destroyed."
