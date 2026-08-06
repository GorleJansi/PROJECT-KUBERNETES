#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/install-aws-cli.sh"
"$SCRIPT_DIR/install-kubectl.sh"
"$SCRIPT_DIR/install-eksctl.sh"

echo
echo "========================================"
echo "Tool installation complete"
echo "========================================"

aws --version
kubectl version --client
eksctl version
