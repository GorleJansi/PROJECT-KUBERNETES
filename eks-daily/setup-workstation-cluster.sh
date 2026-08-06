#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

run_as_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

install_packages() {
    if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y unzip tar gzip coreutils
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y unzip tar gzip coreutils
    elif command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y curl unzip tar gzip coreutils
    else
        echo "WARNING: supported package manager not found."
        echo "Expecting curl, unzip, tar, gzip, and sha256sum to already exist."
    fi
}

require_curl() {
    if command -v curl >/dev/null 2>&1; then
        return
    fi

    if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y curl-minimal
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y curl-minimal
    else
        echo "ERROR: curl command not found"
        exit 1
    fi
}

install_aws_cli() {
    if command -v aws >/dev/null 2>&1; then
        aws --version
        return
    fi

    case "$(uname -m)" in
        x86_64) AWS_ARCH="x86_64" ;;
        aarch64|arm64) AWS_ARCH="aarch64" ;;
        *)
            echo "ERROR: unsupported CPU architecture for AWS CLI: $(uname -m)"
            exit 1
            ;;
    esac

    WORK_DIR="$(mktemp -d)"
    (
        cd "$WORK_DIR"
        curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
          -o awscliv2.zip
        unzip -q -u awscliv2.zip
        run_as_root ./aws/install \
          --bin-dir /usr/local/bin \
          --install-dir /usr/local/aws-cli
    )
    rm -rf "$WORK_DIR"
    aws --version
}

install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        kubectl version --client
        return
    fi

    case "$(uname -m)" in
        x86_64) KUBECTL_ARCH="amd64" ;;
        aarch64|arm64) KUBECTL_ARCH="arm64" ;;
        *)
            echo "ERROR: unsupported CPU architecture for kubectl: $(uname -m)"
            exit 1
            ;;
    esac

    KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
    WORK_DIR="$(mktemp -d)"
    (
        cd "$WORK_DIR"
        curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
        curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl.sha256"
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
        run_as_root install -m 0755 kubectl /usr/local/bin/kubectl
    )
    rm -rf "$WORK_DIR"
    kubectl version --client
}

install_eksctl() {
    if command -v eksctl >/dev/null 2>&1; then
        eksctl version
        return
    fi

    case "$(uname -m)" in
        x86_64) EKSCTL_ARCH="amd64" ;;
        aarch64|arm64) EKSCTL_ARCH="arm64" ;;
        *)
            echo "ERROR: unsupported CPU architecture for eksctl: $(uname -m)"
            exit 1
            ;;
    esac

    PLATFORM="$(uname -s)_${EKSCTL_ARCH}"
    ARCHIVE="eksctl_${PLATFORM}.tar.gz"
    WORK_DIR="$(mktemp -d)"
    (
        cd "$WORK_DIR"
        curl -fsSLO "https://github.com/eksctl-io/eksctl/releases/latest/download/${ARCHIVE}"
        curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" \
          | grep "${ARCHIVE}" \
          | sha256sum --check
        tar -xzf "$ARCHIVE" -C "$WORK_DIR"
        run_as_root install -m 0755 "$WORK_DIR/eksctl" /usr/local/bin/eksctl
    )
    rm -rf "$WORK_DIR"
    eksctl version
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found after install: $1"
        exit 1
    }
}

cluster_exists() {
    aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      >/dev/null 2>&1
}

nodegroup_exists() {
    aws eks describe-nodegroup \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      >/dev/null 2>&1
}

wait_for_cluster() {
    aws eks wait cluster-active \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION"
}

wait_for_nodegroup() {
    aws eks wait nodegroup-active \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION"
}

create_cluster() {
    eksctl create cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --managed \
      --nodes "$DESIRED_NODES" \
      --nodes-min 0 \
      --nodes-max "$MAX_NODES" \
      --node-type "$NODE_TYPE" \
      --nodegroup-name "$NODEGROUP_NAME"
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

scale_nodegroup_if_needed() {
    CURRENT_DESIRED=$(aws eks describe-nodegroup \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      --query 'nodegroup.scalingConfig.desiredSize' \
      --output text)

    if [[ "$CURRENT_DESIRED" == "$DESIRED_NODES" ]]; then
        echo "Node group already has desired size: $DESIRED_NODES"
        return
    fi

    echo "Scaling node group from $CURRENT_DESIRED to $DESIRED_NODES nodes..."
    aws eks update-nodegroup-config \
      --cluster-name "$CLUSTER_NAME" \
      --nodegroup-name "$NODEGROUP_NAME" \
      --region "$AWS_REGION" \
      --scaling-config minSize=0,maxSize="$MAX_NODES",desiredSize="$DESIRED_NODES" \
      --query 'update.{ID:id,Status:status}' \
      --output table

    wait_for_nodegroup
}

wait_for_ready_nodes() {
    echo "Waiting for Kubernetes nodes to become Ready..."

    for _ in $(seq 1 40); do
        READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null |
            awk '$2 == "Ready" {count++} END {print count+0}')

        echo "Ready nodes: $READY_NODES/$DESIRED_NODES"

        if [[ "$READY_NODES" -ge "$DESIRED_NODES" ]]; then
            return
        fi

        sleep 30
    done

    echo "ERROR: Nodes did not become Ready."
    kubectl get nodes -o wide || true
    exit 1
}

echo "========================================"
echo "EC2 workstation and EKS cluster setup"
echo "========================================"
echo
echo "Target:"
echo "  Cluster:   $CLUSTER_NAME"
echo "  Region:    $AWS_REGION"
echo "  Nodegroup: $NODEGROUP_NAME"
echo "  Nodes:     $DESIRED_NODES"
echo "  Node type: $NODE_TYPE"
echo
echo "This installs tools and can create billable AWS resources."
read -r -p "Type SETUP to continue: " CONFIRMATION

if [[ "$CONFIRMATION" != "SETUP" ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo
echo "1. Installing workstation tools..."
install_packages
require_curl
install_aws_cli
install_kubectl
install_eksctl

require_command aws
require_command kubectl
require_command eksctl
require_command awk

echo
echo "2. Checking AWS identity..."
aws sts get-caller-identity \
  --query '{Account:Account,User:Arn}' \
  --output table

echo
echo "3. Creating or reusing EKS cluster..."
if cluster_exists; then
    CLUSTER_STATUS=$(aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --query 'cluster.status' \
      --output text)
    echo "Cluster already exists with status: $CLUSTER_STATUS"
else
    create_cluster
fi

wait_for_cluster

echo
echo "4. Creating or reusing managed node group..."
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
    create_nodegroup
    wait_for_nodegroup
fi

scale_nodegroup_if_needed

echo
echo "5. Updating kubeconfig..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "6. Verifying cluster..."
wait_for_ready_nodes

kubectl get nodes \
  -L eks.amazonaws.com/capacityType,node.kubernetes.io/instance-type

echo
echo "Node groups:"
eksctl get nodegroup \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION"

echo
echo "========================================"
echo "WORKSTATION AND EKS CLUSTER READY"
echo "========================================"
echo
echo "Next commands:"
echo "  $SCRIPT_DIR/status.sh"
echo "  $SCRIPT_DIR/practice.sh"
