#!/usr/bin/env bash

set -Eeuo pipefail

run_as_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v terraform >/dev/null 2>&1; then
    terraform version
    exit 0
fi

if command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y dnf-plugins-core
    run_as_root dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    run_as_root dnf -y install terraform
elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y yum-utils
    run_as_root yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    run_as_root yum -y install terraform
elif command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y gnupg software-properties-common wget
    wget -O- https://apt.releases.hashicorp.com/gpg |
        gpg --dearmor |
        run_as_root tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" |
        run_as_root tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    run_as_root apt-get update
    run_as_root apt-get install -y terraform
else
    echo "ERROR: supported package manager not found. Install Terraform manually."
    exit 1
fi

terraform version
