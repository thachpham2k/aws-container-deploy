#!/usr/bin/env bash

script_name=delete_ecr.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="

echo "repo_name='$repo_name'"
echo "region='$region'"

echo "==================== BEGIN ===================="

echo "Delete image in ECR..."
aws ecr batch-delete-image \
      --repository-name $repo_name \
      --image-ids imageTag=latest \
      --region $region

echo "Delete Repository..."
aws ecr delete-repository \
    --repository-name $repo_name \
    --force \
    --region $region

echo "==================== END ===================="