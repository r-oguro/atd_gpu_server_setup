#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

OUTPUT_DIR="${1:-$PWD/offline-packages}"
DEB_DIR="${OUTPUT_DIR}/debs"
PACKAGE_LIST="${OUTPUT_DIR}/installed-packages.txt"
PACKAGE_SPECS="${OUTPUT_DIR}/installed-package-specs.txt"

mkdir -p "${DEB_DIR}"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
    apt-get update
    apt-get install -y dpkg-dev
fi

apt-get update

dpkg-query -W -f='${binary:Package} ${db:Status-Abbrev}\n' \
    | awk '$2 == "ii" { print $1 }' \
    | sort -u \
    > "${PACKAGE_LIST}"

dpkg-query -W -f='${binary:Package}=${Version} ${db:Status-Abbrev}\n' \
    | awk '$2 == "ii" { print $1 }' \
    | sort -u \
    > "${PACKAGE_SPECS}"

mapfile -t package_specs < "${PACKAGE_SPECS}"
if [[ "${#package_specs[@]}" -eq 0 ]]; then
    echo "No installed packages were found." >&2
    exit 1
fi

find "${DEB_DIR}" -maxdepth 1 -type f -name '*.deb' -delete
apt-get --download-only --reinstall --no-remove \
    -o Dir::Cache::archives="${DEB_DIR}" \
    install "${package_specs[@]}"

(
    cd "${DEB_DIR}"
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
)

cat > "${OUTPUT_DIR}/README.txt" <<EOF
Offline APT package repository

Package names: ${PACKAGE_LIST}
Package versions: ${PACKAGE_SPECS}
Debian packages: ${DEB_DIR}

APT source when mounted at /mnt/offline-packages:
  deb [trusted=yes] file:/mnt/offline-packages/debs ./
EOF

echo "Created offline package repository: ${OUTPUT_DIR}"
echo "Package files: $(find "${DEB_DIR}" -maxdepth 1 -type f -name '*.deb' | wc -l)"
