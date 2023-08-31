#!/usr/bin/env bash

script_name=delete_iam_role_n_instance_profile.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "iam_role_name='$iam_role_name'"
echo "iam_profile_name='$iam_profile_name'"
echo "iam_default_policies=${iam_default_policies[@]}"
echo "iam_custom_policy_name='$iam_custom_policy_name'"
echo "iam_custom_policy_file='$iam_custom_policy_file'"

echo "==================== BEGIN ===================="

echo "Remove Role from Instance Profile..."
aws iam remove-role-from-instance-profile \
    --instance-profile-name $iam_profile_name \
    --role-name $iam_role_name

echo "Delete Instance Profile..."
aws iam delete-instance-profile \
  --instance-profile-name $iam_profile_name

echo "Detach Default policies..."
if [ -z "$iam_default_policies" ]
then
  echo "variable iam_default_policies is empty"
else
  for policy in "${iam_default_policies[@]}"; do
    aws iam detach-role-policy \
      --policy-arn $policy \
      --role-name $iam_role_name
  done;
fi

echo "Delete Custom Policy..."
if [ -z "$iam_custom_policy_name" ] || [ -z "$iam_custom_policy_file" ]
then
  echo "variable iam_custom_policy_name or iam_custom_policy_file is empty"
else
  aws iam delete-role-policy \
    --role-name $iam_role_name \
    --policy-name $iam_custom_policy_name
fi

echo "Delete Role..."
aws iam delete-role --role-name $iam_role_name

echo "==================== END ===================="