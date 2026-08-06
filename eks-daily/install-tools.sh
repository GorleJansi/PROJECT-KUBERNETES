#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/install-aws-cli.sh"
"$SCRIPT_DIR/install-kubectl.sh"
"$SCRIPT_DIR/install-terraform.sh"

echo
echo "========================================"
echo "Tool installation complete"
echo "========================================"

aws --version
kubectl version --client
terraform version
