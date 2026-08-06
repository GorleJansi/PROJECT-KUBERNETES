#!/usr/bin/env bash

set -Eeuo pipefail

run_as_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

install_packages() {
    if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y coreutils
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y coreutils
    elif command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y curl coreutils
    else
        echo "WARNING: supported package manager not found. Expecting curl and sha256sum to already exist."
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

case "$(uname -m)" in
    x86_64)
        KUBECTL_ARCH="amd64"
        ;;
    aarch64|arm64)
        KUBECTL_ARCH="arm64"
        ;;
    *)
        echo "ERROR: unsupported CPU architecture: $(uname -m)"
        exit 1
        ;;
esac

install_packages
require_curl

KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"
curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

run_as_root install -m 0755 kubectl /usr/local/bin/kubectl

kubectl version --client
