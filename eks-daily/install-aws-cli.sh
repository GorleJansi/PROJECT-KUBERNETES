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
        run_as_root dnf install -y curl unzip
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y curl unzip
    elif command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y curl unzip
    else
        echo "WARNING: supported package manager not found. Expecting curl and unzip to already exist."
    fi
}

case "$(uname -m)" in
    x86_64)
        AWS_ARCH="x86_64"
        ;;
    aarch64|arm64)
        AWS_ARCH="aarch64"
        ;;
    *)
        echo "ERROR: unsupported CPU architecture: $(uname -m)"
        exit 1
        ;;
esac

install_packages

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
  -o awscliv2.zip

unzip -q -u awscliv2.zip

if [[ -d /usr/local/aws-cli ]]; then
    run_as_root ./aws/install \
      --bin-dir /usr/local/bin \
      --install-dir /usr/local/aws-cli \
      --update
else
    run_as_root ./aws/install \
      --bin-dir /usr/local/bin \
      --install-dir /usr/local/aws-cli
fi

aws --version
