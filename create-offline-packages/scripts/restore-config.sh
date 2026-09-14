#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
CONFIG_ARCHIVE="${1:-/cdrom/config/current-system-config.tar.zst}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

if [[ ! -f "${CONFIG_ARCHIVE}" ]]; then
    echo "Configuration archive not found; skipping: ${CONFIG_ARCHIVE}"
    exit 0
fi

tar --zstd -xpf "${CONFIG_ARCHIVE}" -C /
systemctl daemon-reload || true

echo "Restored configuration from ${CONFIG_ARCHIVE}"
