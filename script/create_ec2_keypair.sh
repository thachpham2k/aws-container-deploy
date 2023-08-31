#!/usr/bin/env bash
script_name=create_ec2_keypair.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "keypair_name='$keypair_name'"
echo "region='$region'"
echo "tagspec='$tagspec'"
echo "keypair_dst='$keypair_dst'"

# SSH Keypair
echo "==================== BEGIN Key pair ===================="

## Create Keypair
echo "Create Keypair..."
aws ec2 create-key-pair \
    --key-name $keypair_name \
    --region $region \
    --tag-specifications `echo 'ResourceType=key-pair,Tags=['$tagspec`] \
    --query 'KeyMaterial' \
    --output text > $keypair_dst

echo "==================== Key name ===================="

echo "keypair_name='$keypair_name'"

echo "==================== END Security Group ===================="