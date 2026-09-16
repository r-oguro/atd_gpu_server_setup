#!/bin/bash
set -euo pipefail
set -x

export DEBIAN_FRONTEND=noninteractive
CUDA_TOOLKIT_PACKAGE="${CUDA_TOOLKIT_PACKAGE:-cuda-toolkit-13-3}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root." >&2
    exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

VERSION=$(lsb_release -rs | tr -d '.')
if [ ! "$VERSION" = "2404" ] && [ ! "$VERSION" = "2604" ]; then
    echo "Unsupported Ubuntu version: $VERSION"
    echo "CUDA toolkit installation completed."
    exit 0
fi

curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${VERSION}/x86_64/cuda-keyring_1.1-1_all.deb" \
    -o /tmp/cuda-keyring.deb
dpkg -i /tmp/cuda-keyring.deb
rm -f /tmp/cuda-keyring.deb
apt-get update
set +e
apt-get install -y "${CUDA_TOOLKIT_PACKAGE}" || true
set -e

cat > /etc/profile.d/cuda.sh <<'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/lib:${LD_LIBRARY_PATH:-}
export TF_FORCE_GPU_ALLOW_GROWTH=true
export CUDA_DEVICE_ORDER=PCI_BUS_ID
EOF

echo "CUDA toolkit installation completed."
