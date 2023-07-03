# Create ECS

## Variable init
```shell
# global architect
region=ap-southeast-1
az_01=ap-southeast-1a
az_02=ap-southeast-1b
# tags
tags='[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]'
tags2='[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
tagspec=Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]
vpc_tagspec='ResourceType=vpc,Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
subnet_tagspec='ResourceType=subnet,Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
# SecretManager
database_psswd=db-1357
# ECS
cluster_name=aws-container-deploy-cluster
backend_task_definition=backend-td
proxy_task_definition=nginx-td
database_task_definition=database-td
backend_image=???
proxy_image=???
# network
vpc_cidr=10.0.0.0/16
pubsubnet1_cidr=10.0.0.0/20
pubsubnet2_cidr=10.0.16.0/20
prisubnet1_cidr=10.0.128.0/20
prisubnet2_cidr=10.0.144.0/20
# security and other
role_name=aws-container-deploy-role
key_name=aws-container-deploy-keypair
sgr_name=aws-container-deploy-sgr
```

## Create ECS Cluster
```shell
aws ecs create-cluster \
    --cluster-name $cluster_name \
    --region $region \
    --tags $tags

# Check ECS Cluster created correctly
aws ecs list-clusters
```

## Create network
```shell
# Create VPC and Enable dns-hostname feature in vpc
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo "ResourceType=vpc,$tagspec"` \
    --output text \
    --query 'Vpc.VpcId')

aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'

# Create subnet
subnet_public_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $pubsubnet1_cidr \
    --tag-specifications `echo "ResourceType=subnet,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications `echo "ResourceType=subnet,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications `echo "ResourceType=subnet,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications `echo "ResourceType=subnet,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

# Create Internet Gateway
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --tag-specifications `echo "ResourceType=internet-gateway,$tagspec"` \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id

public_route_table_id=$(aws ec2 create-route-table \
    --tag-specifications `echo "ResourceType=route-table,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.RouteTable.RouteTableId')

aws ec2 create-route \
    --route-table-id $public_route_table_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $gateway_id

# Associate each public subnet with the public route table
aws ec2 associate-route-table \
    --subnet-id $subnet_public_1 \
    --route-table-id $public_route_table_id

aws ec2 associate-route-table \
    --subnet-id $subnet_public_2 \
    --route-table-id $public_route_table_id
```
## Create keypair
```shell
# Create Keypair
aws ec2 create-key-pair \
    --key-name $key_name \
    --region $region \
    --tag-specifications `echo "ResourceType=key-pair,$tagspec"` \
    --query 'KeyMaterial' \
    --output text > ./$key_name.pem
```

## Create EC2
```shell
# Create Security Group
security_group_id=$(aws ec2 create-security-group \
    --group-name $sgr_name \
    --description "Security group for EC2 in ECS" \
    --tag-specifications `echo "ResourceType=security-group,$tagspec"` \
    --vpc-id $vpc_id | jq -r '.GroupId')

aws ec2 authorize-security-group-ingress \
   --group-id $security_group_id \
   --protocol tcp \
   --port 8080 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $security_group_id \
   --protocol tcp \
   --port 22 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $security_group_id \
   --protocol tcp \
   --port 5432 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $security_group_id \
   --protocol tcp \
   --port 80 \
   --cidr 0.0.0.0/0

# Create EC2 Role
aws iam create-role \
    --role-name $role_name \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "Service": ["ec2.amazonaws.com"]
            },
            "Action": ["sts:AssumeRole"]
        }]
    }' \
    --tags = $tags

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role \
    --role-name $role_name

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
    --role-name $role_name

aws iam create-instance-profile \
    --instance-profile-name $role_name

aws iam add-role-to-instance-profile \
    --instance-profile-name $role_name \
    --role-name $role_name

# Get ECS AMI ID
[get ecs ami](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html)
ecs_ami=$(aws ssm get-parameters \
    --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
    --region $region | jq -r '.Parameters[0].Value | fromjson.image_id')

# Create EC2
ecs_instance_id=$(aws ec2 run-instances \
    --image-id $ecs_ami \
    --count 1 \
    --instance-type t2.micro \
    --subnet-id $subnet_public_1 \
    --key-name $key_name \
    --security-group-ids $security_group_id \
    --associate-public-ip-address \
    --user-data '#!/bin/bash
echo ECS_CLUSTER=aws-container-deploy >> /etc/ecs/ecs.config' \
    --tag-specifications `echo "ResourceType=instance,$tagspec"` | jq -r '.Instances[0].InstanceId')

aws ec2 associate-iam-instance-profile \
    --instance-id $ecs_instance_id \
    --iam-instance-profile Name=$role_name
```

## Create Secret Manager
```shell
aws secretsmanager create-secret \
    --name databaseSecret \
    --description "To save database information" \
    --tags $tags2 \
    --secret-string `echo "{\"user\":\"root\",\"POSTGRES_PASSWORD\":\"$database_psswd\"}"`
    
# --secret-string file://../src/database/password.txt
```

## Create Task Definition for portgress database
```shell
# Get ARN of AWS secret manager
sm_databasepsswd_arn=$(aws secretsmanager describe-secret --secret-id databaseSecret --query 'ARN' --output text)

# Create Task Definition for portgress database
ecs_database_task_definition=$(aws ecs register-task-definition \
    --family $database_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --tags $tags \
    --container-definitions '[
        {
            "name": "$database_task_definition",
            "image": "postgres",
            "essential": true,
            "restartPolicy" : {
                "condition" :	"RESTART_POLICY",
                "maximumRetryCount" :	123
            },
            "portMappings": [
                {
                    "containerPort": 5432,
                    "hostPort": 5432
                }
            ],
            "environment" : [
                {
                    "name" : "POSTGRES_DB",
                    "value" : "example"
                },
                {
                    "name" : "POSTGRES_PASSWORD",
                    "value" : "$sm_databasepsswd_arn:POSTGRES_PASSWORD"
                }
            ]
        }
    ]')

# Check ECS task definition created correctly
aws ecs list-task-definitions
```

## Create Task Definition for Backend
```shell
ecs_backend_task_definition=$(aws ecs register-task-definition \
    --family $backend_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --tags $tags \
    --container-definitions '[
        {
            "name": "$backend_task_definition",
            "image": "$backend_image",
            "portMappings": [
                {
                    "containerPort": 8080,
                    "hostPort": 8080
                }
            ]
        }
    ]')

# Check ECS task definition created correctly
aws ecs list-task-definitions
```

## Create Task Definition for Nginx
```shell
ecs_proxy_task_definition=$(aws ecs register-task-definition \
    --family $proxy_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --tags $tags \
    --container-definitions '[
        {
            "name": "$proxy_task_definition",
            "image": "$proxy_image",
            "portMappings": [
                {
                    "containerPort": 80,
                    "hostPort": 80
                }
            ]
        }
    ]')

# Check ECS task definition created correctly
aws ecs list-task-definitions
```

## Create Service
```shell
# aws ecs register-container-instance --cluster aws-container-deploy --instance-id $ecs_instance_id
# Database
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $database_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
aws ecs create-service \
   --cluster aws-container-deploy \
   --service-name aws-container-deploy-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"

# Backend
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $backend_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
aws ecs create-service \
   --cluster aws-container-deploy \
   --service-name aws-container-deploy-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"

# Nginx
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $proxy_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
aws ecs create-service \
   --cluster aws-container-deploy \
   --service-name aws-container-deploy-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"
```


```shell
aws secretsmanager delete-secret --secret-id databaseSecret
aws ec2 delete-key-pair --key-name aws-container-deploy-keypair
aws ec2 delete-security-group --group-id $security_group_id
aws ec2 delete-subnet --subnet-id $subnet_public_1
aws ec2 delete-subnet --subnet-id $subnet_public_2
aws ec2 delete-subnet --subnet-id $subnet_private_1
aws ec2 delete-subnet --subnet-id $subnet_private_2
aws ec2 delete-route-table --route-table-id $public_route_table_id
aws ec2 detach-internet-gateway --internet-gateway-id $gateway_id --vpc-id $vpc_id
aws ec2 delete-internet-gateway --internet-gateway-id $gateway_id
aws ec2 delete-vpc --vpc-id $vpc_id
```


## Delete ECS Cluster
```shell
aws ecs delete-cluster --cluster awsContainerDeploy
```
