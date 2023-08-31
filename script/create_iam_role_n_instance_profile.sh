#!/usr/bin/env bash
script_name=create_iam_role_n_instance_profile.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "Input..."
echo "tag2='$tag2'"
echo "iam_role_name='$iam_role_name'"
echo "iam_profile_name='$iam_profile_name'"
echo "iam_principal_service='$iam_principal_service'"
echo "iam_default_policies=${iam_default_policies[@]}"
echo "iam_custom_policy_name='$iam_custom_policy_name'"
echo "iam_custom_policy_file='$iam_custom_policy_file'"

echo "==================== BEGIN ===================="

# IAM Role
## Create IAM role
echo "Create Role..."
cat <<EOF | tee assume_role_policy_document.json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": [`echo $iam_principal_service`]
    },
    "Action": ["sts:AssumeRole"]
  }]
}
EOF
aws iam create-role \
  --role-name $iam_role_name \
  --assume-role-policy-document "`cat assume_role_policy_document.json`" \
  --tags "$tags"
rm assume_role_policy_document.json

## Attach default policy
echo "Attach default policy..."
if [ -z "$iam_default_policies" ]
then
  echo "variable iam_default_policies is empty"
else
  for policy in "${iam_default_policies[@]}"; do
    aws iam attach-role-policy \
    --policy-arn $policy \
    --role-name $iam_role_name
  done;
fi

## Custom policy
echo "Attach default policy..."
if [ -z "$iam_custom_policy_name" ] || [ -z "$iam_custom_policy_file" ]
then
  echo "variable iam_custom_policy_name or iam_custom_policy_file is empty"
else
  aws iam put-role-policy \
    --role-name $iam_role_name \
    --policy-name $iam_custom_policy_name \
    --policy-document file://$iam_custom_policy_file
fi

## Create Instance Profile
echo "Create Instance Profile..."
aws iam create-instance-profile \
  --instance-profile-name $iam_profile_name

## Add Role to profile
echo "Add role to Instance Profile..."
aws iam add-role-to-instance-profile \
  --instance-profile-name $iam_profile_name \
  --role-name $iam_role_name

echo "==================== OUTPUT ===================="

echo "Get Role ARN..."
iam_role_arn=$(aws iam get-role \
  --role-name $iam_role_name \
  --output text \
  --query 'Role.Arn')

echo "Get IAM Instance Profile ARN..."
iam_profile_arn=$(aws iam get-instance-profile \
  --instance-profile-name $iam_profile_name \
  --output text \
  --query 'InstanceProfile.Arn')
  
echo "iam_role_arn='$iam_role_arn'"
echo "iam_profile_arn='$iam_profile_arn'"

echo "==================== END ===================="