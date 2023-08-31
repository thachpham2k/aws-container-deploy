#!/usr/bin/env bash

script_name=create_network_3az.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "region='$region'"
echo "az_01='$az_01'"
echo "az_02='$az_02'"
echo "az_03='$az_03'"
echo "tagspec='$tagspec'"
echo "vpc_cidr='$vpc_cidr'"
echo "pubsubnet1_cidr='$pubsubnet1_cidr'"
echo "pubsubnet2_cidr='$pubsubnet2_cidr'"
echo "pubsubnet3_cidr='$pubsubnet3_cidr'"
echo "prisubnet1_cidr='$prisubnet1_cidr'"
echo "prisubnet2_cidr='$prisubnet2_cidr'"
echo "prisubnet3_cidr='$prisubnet3_cidr'"

echo "vpc_name='$vpc_name'"
echo "pubsubnet1_name='$pubsubnet1_name'"
echo "pubsubnet2_name='$pubsubnet2_name'"
echo "pubsubnet3_name='$pubsubnet3_name'"
echo "prisubnet1_name='$prisubnet1_name'"
echo "prisubnet2_name='$prisubnet2_name'"
echo "prisubnet3_name='$prisubnet3_name'"
echo "igw_name='$igw_name'"
echo "rtb_name='$rtb_name'"

echo "==================== BEGIN ===================="

# VPC
echo "===== VPC ====="

## Create VPC
echo "Create VPC...."
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo 'ResourceType=vpc,Tags=[{Key=Name,Value='$vpc_name'},'$tagspec`] \
    --output text \
    --query 'Vpc.VpcId')

## Enable dns-hostname feature in vpc
echo "Enable dns-hostname for vpc..."
aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'

# Subnet
echo "===== Subnet ====="

## Create subnet
echo "Create PublicSubnet..."
subnet_public_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $pubsubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet1_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')
subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet2_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')
subnet_public_3=$(aws ec2 create-subnet \
    --availability-zone $az_03 \
    --cidr-block $pubsubnet3_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet3_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')

echo "Create Private Subnet..."
subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet1_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')
subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet2_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')
subnet_private_3=$(aws ec2 create-subnet \
    --availability-zone $az_03 \
    --cidr-block $prisubnet3_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet3_name'},'$tagspec`] \
    --vpc-id $vpc_id \
    --output text \
    --query 'Subnet.SubnetId')

## Enable feature auto allocate Public IP for EC2 in Public Subnet
echo "Enable auto-allocate public IP..."
aws ec2 modify-subnet-attribute \
  --subnet-id $subnet_public_1 \
  --map-public-ip-on-launch
aws ec2 modify-subnet-attribute \
  --subnet-id $subnet_public_2 \
  --map-public-ip-on-launch
aws ec2 modify-subnet-attribute \
  --subnet-id $subnet_public_3 \
  --map-public-ip-on-launch

# Internet Gateway
echo "===== Internet Gateway ====="

## Create Internet Gateway
echo "Create Internet Gateway..."
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --tag-specifications `echo 'ResourceType=internet-gateway,Tags=[{Key=Name,Value='$igw_name'},'$tagspec`] \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

## Attach this into VPC
echo "Attach internet gateway to VPC..."
aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id

# RouteTable
echo "===== Route Table ====="

## Create Route table
echo "Create Route table..."
rtb_public_id=$(aws ec2 create-route-table \
    --tag-specifications `echo 'ResourceType=route-table,Tags=[{Key=Name,Value='$rtb_name'},'$tagspec`] \
    --vpc-id $vpc_id | jq -r '.RouteTable.RouteTableId')

## Routing to Internet Gateway
echo "Routing to Internet Gateway..."
aws ec2 create-route \
    --route-table-id $rtb_public_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $gateway_id

## Associate each public subnet with the public route table
echo "Associate RouteTable to Public Subnet..."
aws ec2 associate-route-table \
    --subnet-id $subnet_public_1 \
    --route-table-id $rtb_public_id
aws ec2 associate-route-table \
    --subnet-id $subnet_public_2 \
    --route-table-id $rtb_public_id
aws ec2 associate-route-table \
    --subnet-id $subnet_public_3 \
    --route-table-id $rtb_public_id
    
echo "==================== OUTPUT ===================="

echo "vpc_id='$vpc_id'"
echo "subnet_public_1='$subnet_public_1'"
echo "subnet_public_2='$subnet_public_2'"
echo "subnet_public_3='$subnet_public_3'"
echo "subnet_private_1='$subnet_private_1'"
echo "subnet_private_2='$subnet_private_2'"
echo "subnet_private_3='$subnet_private_3'"
echo "gateway_id='$gateway_id'"
echo "rtb_public_id='$rtb_public_id'"

echo "==================== END ===================="