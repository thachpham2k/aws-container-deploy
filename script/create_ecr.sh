#!/usr/bin/env bash

script_name=create_ecr.sh
echo "==================== SCRIPT $script_name ===================="

echo "==================== INPUT ===================="
echo "repo_name='$repo_name'"
echo "region='$region'"
echo "tags='$tags'"
echo "src_dir='$src_dir'"

echo "==================== BEGIN ===================="

echo "Get Account ID..."
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)

echo "Login to AWS ECR..."
# Private ECR repository
aws ecr get-login-password \
  --region $region | docker login \
  --username AWS \
  --password-stdin `aws sts get-caller-identity --query 'Account' --output text`.dkr.ecr.$region.amazonaws.com
# Public ecr
# aws ecr-public get-login-password --region $region | docker login --username AWS --password-stdin public.ecr.aws/ecr_id
# -> Docker Credential will save to ~/.docker/config.json file

echo "Create ECR repository..."
aws ecr create-repository \
  --repository-name $repo_name \
  --region $region \
  --tags "$tags"

echo "Docker Build & Tags..."
docker build -t $repo_name $src_dir
# check Docker image created correctly
docker images --filter reference=$repo_name
# Tag the image to push to your repository.
docker tag $repo_name:latest $aws_account_id.dkr.ecr.$region.amazonaws.com/$repo_name

echo "Push to AWS ECR..."
docker push $aws_account_id.dkr.ecr.$region.amazonaws.com/$repo_name

echo "==================== OUTPUT ===================="

ecr_image_uri=$aws_account_id.dkr.ecr.$region.amazonaws.com/$repo_name:latest
echo "ecr_image_uri='$ecr_image_uri'"

echo "==================== END ===================="