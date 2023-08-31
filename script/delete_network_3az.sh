#!/usr/bin/env bash
script_name=delete_network_3az.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "vpc_id='$vpc_id'"
echo "subnet_public_1='$subnet_public_1'"
echo "subnet_public_2='$subnet_public_2'"
echo "subnet_public_3='$subnet_public_3'"
echo "subnet_private_1='$subnet_private_1'"
echo "subnet_private_2='$subnet_private_2'"
echo "subnet_private_3='$subnet_private_3'"
echo "gateway_id='$gateway_id'"
echo "rtb_public_id='$rtb_public_id'"

echo "==================== BEGIN ===================="

echo "Delete Subnet..."
aws ec2 delete-subnet --subnet-id $subnet_public_1
aws ec2 delete-subnet --subnet-id $subnet_public_2
aws ec2 delete-subnet --subnet-id $subnet_public_3
aws ec2 delete-subnet --subnet-id $subnet_private_1
aws ec2 delete-subnet --subnet-id $subnet_private_2
aws ec2 delete-subnet --subnet-id $subnet_private_3

echo "Delete Route Table..."
aws ec2 delete-route-table --route-table-id $rtb_public_id

echo "Detach Internet Gateway..."
aws ec2 detach-internet-gateway \
    --internet-gateway-id $gateway_id \
    --vpc-id $vpc_id

echo "Delete Internet Gateway..."
aws ec2 delete-internet-gateway --internet-gateway-id $gateway_id

echo "Delete VPC..."
aws ec2 delete-vpc --vpc-id $vpc_id

echo "==================== END ===================="