#!/usr/bin/env bash

script_name=install_eksctl.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
# ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
echo "ARCH='$ARCH'"
echo "PLATFORM='$PLATFORM'"

echo "==================== BEGIN ===================="

current_dir=`pwd`

cd ~
# Download the Package (curl --silent --location)
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
# extract
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv -v /tmp/eksctl /usr/local/bin

cd $current_dir

echo "==================== OUTPUT ===================="

eksctl info

echo "==================== END ===================="