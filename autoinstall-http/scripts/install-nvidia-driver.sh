#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
NVIDIA_DRIVER_PACKAGE="${NVIDIA_DRIVER_PACKAGE:-nvidia-driver-595-server-open}"
FABRIC_MANAGER_PACKAGE="${FABRIC_MANAGER_PACKAGE:-nvidia-fabricmanager-595}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

apt-get update
apt-get install -y pciutils

# Fabric Manager is required for systems with NVSwitch hardware.
if lspci -nn | grep -Eqi 'nvswitch|nvidia.*switch'; then
    echo "NVSwitch detected; installing ${FABRIC_MANAGER_PACKAGE}."
    apt-get install -y "${FABRIC_MANAGER_PACKAGE}"
else
    echo "NVSwitch not detected; skipping Fabric Manager."
fi

apt-get install -y "${NVIDIA_DRIVER_PACKAGE}"

# CUDA Toolkit from the Ubuntu standard repository
apt-get install -y cuda-toolkit-13-1

# NCCL runtime and development packages
apt-get install -y libnccl2 libnccl-dev
