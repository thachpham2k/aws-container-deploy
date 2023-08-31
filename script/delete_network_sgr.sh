#!/usr/bin/env bash

script_name=delete_network_sgr.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "sgr_id='$sgr_id'"

echo "==================== BEGIN ===================="

echo "Delete Security Group..."
aws ec2 delete-security-group --group-id $sgr_id

echo "==================== END ===================="