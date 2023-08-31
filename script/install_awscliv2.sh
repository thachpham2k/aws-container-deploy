#!/usr/bin/env bash

script_name=install_awscliv2.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== BEGIN ===================="

current_dir=`pwd`
# sudo apt install awscli -y
# aws --version
# aws configure
cd ~
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update # hoặc sudo ./aws/install nếu gặp lỗi
cd $current_dir

echo "==================== OUTPUT ===================="

aws --version

echo "==================== END ===================="