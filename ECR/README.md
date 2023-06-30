# Create ECR repository using AWS CLI

## Create Repository
```shell
aws ecr create-repository \
        --repository-name container-image \
        --region ap-southeast-1 \
        --tags '[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
```

## Login to AWS CLI
```shell
# Private ECR repository
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.ap-southeast-1.amazonaws.com
# Public ecr
aws ecr-public get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin public.ecr.aws/ecr_id`
```

## Create Docker image from Dockerfile
```shell
docker build -t container-image .
```

## check Docker image created correctly
```shell
docker images --filter reference=container-image
```

## Tag the image to push to your repository.
```shell
docker tag container-image:latest aws_account_id.dkr.ecr.region.amazonaws.com/container-image
```

## Push to AWS
```shell
docker push aws_account_id.dkr.ecr.region.amazonaws.com/container-image
```

## Pull image from ECR
```shell
docker pull aws_account_id.dkr.ecr.region.amazonaws.com/container-image:latest
```

## Delete image in ECR
```shell
aws ecr batch-delete-image \
      --repository-name container-image \
      --image-ids imageTag=latest \
      --region region
```

## Delete Repository
```shell
aws ecr delete-repository \
    --repository-name container-image \
    --force \
    --region ap-southeast-1
```