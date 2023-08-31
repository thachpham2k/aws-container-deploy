#!/usr/bin/env bash

script_name=install_kubectl.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== BEGIN ===================="

current_dir=`pwd`

cd ~
mkdir kuberctl
cd kuberctl
# Download the Package
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.1/2023-04-19/bin/linux/amd64/kubectl
# Provide execute permissions
chmod +x ./kubectl
# Set the Path by copying to user Home Directory
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
cd $current_dir

echo "==================== OUTPUT ===================="

kubectl version --short --client

echo "==================== END ===================="