#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

REPOSITORY_ROOT="${1:-/cdrom/packages}"
DEB_ROOT="${REPOSITORY_ROOT}/debs"
PACKAGE_SPECS="${REPOSITORY_ROOT}/installed-package-specs.txt"

if [[ ! -d "${DEB_ROOT}" ]]; then
    echo "Offline package repository not found: ${DEB_ROOT}" >&2
    exit 1
fi

if [[ ! -f "${DEB_ROOT}/Packages.gz" ]]; then
    echo "APT index not found: ${DEB_ROOT}/Packages.gz" >&2
    exit 1
fi

cat > /etc/apt/sources.list.d/offline-packages.list <<EOF
# Packages copied from the installation ISO
deb [trusted=yes] file:${DEB_ROOT} ./
EOF

apt-get update

if [[ -f "${PACKAGE_SPECS}" ]]; then
    mapfile -t package_specs < "${PACKAGE_SPECS}"
    if [[ "${#package_specs[@]}" -gt 0 ]]; then
        apt-get install -y --no-download "${package_specs[@]}"
    fi
else
    echo "Package version list not found; skipping package installation: ${PACKAGE_SPECS}" >&2
fi
