#!/usr/bin/env bash
script_name=delete_ec2_keypair.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "keypair_name='$keypair_name'"
echo "keypair_dst='$keypair_dst'"

echo "==================== BEGIN ===================="

echo "Delete Keypair..."
aws ec2 delete-key-pair --key-name $keypair_name
rm -f $keypair_dst

echo "==================== END ===================="