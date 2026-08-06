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
        run_as_root dnf install -y curl tar gzip coreutils
    elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y curl tar gzip coreutils
    elif command -v apt-get >/dev/null 2>&1; then
        run_as_root apt-get update
        run_as_root apt-get install -y curl tar gzip coreutils
    else
        echo "WARNING: supported package manager not found. Expecting curl, tar, gzip, and sha256sum to already exist."
    fi
}

case "$(uname -m)" in
    x86_64)
        EKSCTL_ARCH="amd64"
        ;;
    aarch64|arm64)
        EKSCTL_ARCH="arm64"
        ;;
    *)
        echo "ERROR: unsupported CPU architecture: $(uname -m)"
        exit 1
        ;;
esac

install_packages

PLATFORM="$(uname -s)_${EKSCTL_ARCH}"
ARCHIVE="eksctl_${PLATFORM}.tar.gz"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$WORK_DIR"

curl -fsSLO "https://github.com/eksctl-io/eksctl/releases/latest/download/${ARCHIVE}"
curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" \
  | grep "${ARCHIVE}" \
  | sha256sum --check

tar -xzf "$ARCHIVE" -C "$WORK_DIR"

run_as_root install -m 0755 "$WORK_DIR/eksctl" /usr/local/bin/eksctl

eksctl version
