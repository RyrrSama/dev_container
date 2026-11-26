#!/usr/bin/env bash
set -euo pipefail

echo ">>> 1. Installing prerequisite system packages..."
dnf install -y dnf-plugins-core epel-release
dnf install -y gcc gcc-c++ make cmake git wget curl pkg-config
dnf install -y python3-devel python3-pip

echo ">>> 2. Detecting RHEL version and adding official NVIDIA CUDA repository..."
RHEL_VERSION=$(rpm -E '%{rhel}')
echo "Detected RHEL version: $RHEL_VERSION"

# Set repository and GPG key based on RHEL version
if [ "$RHEL_VERSION" == "8" ]; then
    CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/"
    CUDA_GPG_KEY="https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/7fa2af80.pub"
elif [ "$RHEL_VERSION" == "9" ]; then
    CUDA_REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/"
    CUDA_GPG_KEY="https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/d42bd26fbb00a71ee64e5fdbea5b38e9.pub"
else
    echo "ERROR: Unsupported RHEL version: $RHEL_VERSION"
    exit 1
fi

echo "Using CUDA repository: $CUDA_REPO_URL"
dnf config-manager --add-repo "$CUDA_REPO_URL"
rpm --import "$CUDA_GPG_KEY"

echo ">>> 3. Installing CUDA Toolkit and development tools..."
# Using max_parallel_downloads=1 prevents HTTP/2 CDN stream resets on large RPMs
dnf clean all
dnf install -y cuda-toolkit --setopt=max_parallel_downloads=1
# cuda-samples may not be available in all RHEL versions; attempt install but don't fail if unavailable
dnf install -y cuda-samples --setopt=max_parallel_downloads=1 || echo "Warning: cuda-samples not available, continuing without it"

echo ">>> 4. Setting up library configuration..."
echo "/usr/local/cuda/lib64" > /etc/ld.so.conf.d/cuda.conf
ldconfig

echo ">>> 5. Upgrading pip and installing Python build tools..."
python3 -m pip install --upgrade pip setuptools wheel

echo ">>> 6. Cleaning DNF cache to keep Docker image small..."
dnf clean all
rm -rf /var/cache/dnf/*

echo ">>> 7. Verifying CUDA installation..."
/usr/local/cuda/bin/nvcc --version
echo ">>> CUDA installation complete!"
