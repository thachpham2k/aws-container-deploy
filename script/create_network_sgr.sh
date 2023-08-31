#!/usr/bin/env bash
script_name=create_network_sgr.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "tagspec='$tagspec'"
echo "vpc_id='$vpc_id'"
echo "sgr_name='$sgr_name'"
echo "sgr_rules=${sgr_rules[@]}"
#### NOTE: Get Key of Arry       echo "sgr_rules=${!sgr_rules[@]}"
#### NOTE: Get Value of Array    echo "sgr_rules=${sgr_rules[@]}"

echo "==================== BEGIN ===================="

# Create Security Group
echo "Create Security Group..."
sgr_id=$(aws ec2 create-security-group \
    --group-name $sgr_name \
    --description "Security group for EKS" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=[{Key=Name,Value='$sgr_name'},'$tagspec`] \
    --vpc-id $vpc_id | jq -r '.GroupId')

# Add Rule
echo "Add rule..."
for rule in "${sgr_rules[@]}"; do
    aws ec2 authorize-security-group-ingress \
    --group-id $sgr_id \
    --protocol tcp \
    --port $rule \
    --cidr 0.0.0.0/0
done;

echo "==================== Security Group ID ===================="

echo "sgr_id='$sgr_id'"

echo "==================== END Security Group ===================="