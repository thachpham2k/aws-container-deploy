**Deploy Container into ECS and using ALB to redirect connection, Database is install in ECS**
===

# Project init


<details>
<summary>AWS config</summary>

## AWS config
```shell
sudo apt update -y
sudo apt install jq awscli -y
cat <<EOF | tee ~/.aws/config
[default]
region = ap-southeast-1
output = json
EOF
cat <<EOF | tee ~/.aws/credentials
[default]
aws_access_key_id = abc
aws_secret_access_key = abc
EOF
# -> Add credential to ~/.aws/credentials file or using `aws configure` command
```
</details>

<details>
<summary>Shell Variable</summary>

## Shell Variable
```shell
# Account
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
# project
project=aws-container-deploy-2-ecs
project2=Deploy2ECS
# global architect
region=ap-southeast-1
az_01=ap-southeast-1a
az_02=ap-southeast-1b
# tags
tags='[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]'
tags2='[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
tagspec='{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
# network
vpc_cidr=10.0.0.0/16
pubsubnet1_cidr=10.0.0.0/20
pubsubnet2_cidr=10.0.16.0/20
prisubnet1_cidr=10.0.128.0/20
prisubnet2_cidr=10.0.144.0/20
# SecretManager
database_psswd=db-1357
# ECS
ecs_cluster_name=$project2-cluster
ecs_task_backend_name=backend-td
ecs_task_proxy_name=nginx-td
ecs_task_database_name=database-td
ecs_task_backend_image=$aws_account_id.dkr.ecr.$region.amazonaws.com/backend-image:latest
ecs_task_proxy_image=$aws_account_id.dkr.ecr.$region.amazonaws.com/proxy-image:latest
ecs_task_role_name=$project2-ecs-task-role
ecs_task_policy_name=$project2_task_policy
# security and other
role_name=aws-container-deploy-role
key_name=aws-container-deploy-keypair
sgr_name=aws-container-deploy-sgr
```

# Create Network

<details>
<summary>Create VPC</summary>

## Create VPC
```shell
vpc_name=$project2-vpc
# Create VPC and Enable dns-hostname feature in vpc
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo 'ResourceType=vpc,Tags=[{Key=Name,Value='$vpc_name'},'$tagspec` \
    --output text \
    --query 'Vpc.VpcId')

aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'

echo $vpc_id
```
</details>

<details>
<summary>Create Subnet</summary>

## Create Subnet
```shell
pubsubnet1_name=$project2-pubsubnet-$az_01
pubsubnet2_name=$project2-pubsubnet-$az_02
pubsubnet3_name=$project2-pubsubnet-$az_03
prisubnet1_name=$project2-prisubnet-$az_01
prisubnet2_name=$project2-prisubnet-$az_02
prisubnet3_name=$project2-prisubnet-$az_03
# Create subnet
subnet_public_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $pubsubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet1_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet2_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_3=$(aws ec2 create-subnet \
    --availability-zone $az_03 \
    --cidr-block $pubsubnet3_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$pubsubnet3_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet1_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet2_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_3=$(aws ec2 create-subnet \
    --availability-zone $az_03 \
    --cidr-block $prisubnet3_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$prisubnet3_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

echo $subnet_public_1
echo $subnet_public_2
echo $subnet_public_3
echo $subnet_private_1
echo $subnet_private_2
echo $subnet_private_3
```
</details>

<details>
<summary>Create Internet Gateway</summary>

## Create Internet Gateway
```shell
igw_name=$project2-igw
# Create Internet Gateway
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --tag-specifications `echo 'ResourceType=internet-gateway,Tags=[{Key=Name,Value='$igw_name'},'$tagspec` \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id

echo $gateway_id
```
</details>

<details>
<summary>Create Routetable and Routing</summary>

## Create Routetable and Routing
```shell
rtb_name=$project2-rtb
# Create Route table
rtb_public_id=$(aws ec2 create-route-table \
    --tag-specifications `echo 'ResourceType=route-table,Tags=[{Key=Name,Value='$rtb_name'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.RouteTable.RouteTableId')

aws ec2 create-route \
    --route-table-id $rtb_public_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $gateway_id

# Associate each public subnet with the public route table
aws ec2 associate-route-table \
    --subnet-id $subnet_public_1 \
    --route-table-id $rtb_public_id

aws ec2 associate-route-table \
    --subnet-id $subnet_public_2 \
    --route-table-id $rtb_public_id

aws ec2 associate-route-table \
    --subnet-id $subnet_public_3 \
    --route-table-id $rtb_public_id

echo $rtb_public_id
```
</details>

# Create Secret Manager

<details>
<summary>Create Secret Manager</summary>

```shell
secret_name=$project2-secret
secret_string=$(echo "{\"POSTGRES_PASSWORD\":\"$database_psswd\"}")
# Create SecretManager
aws secretsmanager create-secret \
    --name $secret_name \
    --description "To save database password" \
    --tags "$tags2" \
    --secret-string $secret_string
```
</details>

# Create ECS

<details>
<summary>Create ECS Cluster</summary>

## Create ECS Cluster
```shell
ecs_cluster_name=$project2-cluster
# Create ECS Cluster
aws ecs create-cluster \
    --cluster-name $ecs_cluster_name \
    --region $region \
    --tags "$tags"

# Check ECS Cluster created correctly
aws ecs list-clusters
```
</details>

# Create EC2

<details>
<summary>Create Keypair</summary>

## Create Keypair
```shell
ecs_ec2_key_name=$(echo $project2-keypair)
# Create Keypair
aws ec2 create-key-pair \
    --key-name $ecs_ec2_key_name \
    --region $region \
    --tag-specifications `echo 'ResourceType=key-pair,Tags=['$tagspec` \
    --query 'KeyMaterial' \
    --output text > ./$ecs_ec2_key_name.pem
```
</details>
<details>
<summary>Create Security Group</summary>

## Create Security Group
```shell
ecs_ec2_sgr_name=$(echo $project2-ecs-sgr)
# Create Security Group
ecs_ec2_sgr_id=$(aws ec2 create-security-group \
    --group-name $ecs_ec2_sgr_name \
    --description "Security group for EC2 in ECS" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=['$tagspec` \
    --vpc-id $vpc_id | jq -r '.GroupId')

aws ec2 authorize-security-group-ingress \
   --group-id $ecs_ec2_sgr_id \
   --protocol tcp \
   --port 8080 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $ecs_ec2_sgr_id \
   --protocol tcp \
   --port 22 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $ecs_ec2_sgr_id \
   --protocol tcp \
   --port 80 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $ecs_ec2_sgr_id \
   --protocol tcp \
   --port 5432 \
   --cidr 0.0.0.0/0

echo $ecs_ec2_sgr_id
```
</details>
<details>
<summary>Create EC2 Role</summary>

## Create Security Group
```shell
ecs_ec2_role_name=$(echo $project2-ecs-ec2-role)
# Create EC2 Role
aws iam create-role \
    --role-name $ecs_ec2_role_name \
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
    --tags "$tags2"
    
aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role \
    --role-name $ecs_ec2_role_name

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
    --role-name $ecs_ec2_role_name

aws iam create-instance-profile \
    --instance-profile-name $ecs_ec2_role_name

aws iam add-role-to-instance-profile \
    --instance-profile-name $ecs_ec2_role_name \
    --role-name $ecs_ec2_role_name

ecs_ec2_instanceprofile_arn=$(aws iam get-instance-profile \
    --instance-profile-name $ecs_ec2_role_name \
    --output text \
    --query 'InstanceProfile.Arn')
```
</details>
<details>
<summary>Get ECS AMI</summary>

## Get ECS AMI
```shell
# Get ECS AMI ID
# [get ecs ami](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html)
ecs_ec2_ami_id=$(aws ssm get-parameters \
    --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
    --region $region | jq -r '.Parameters[0].Value | fromjson.image_id')

echo $ecs_ec2_ami_id
```
</details>
<details>
<summary>Create EC2</summary>

## Create EC2
```shell
ecs_ec2_subnet_id=$subnet_public_1
ecs_ec2_tag=$project2-ecs-ec2
# Create EC2
cat <<EOF | tee ecs-ec2-userdata.txt
#!/bin/bash
echo ECS_CLUSTER=`echo -n $ecs_cluster_name` >> /etc/ecs/ecs.config
EOF

ecs_ec2_id=$(aws ec2 run-instances \
    --image-id $ecs_ec2_ami_id \
    --count 1 \
    --instance-type t3.medium \
    --subnet-id $ecs_ec2_subnet_id \
    --key-name $ecs_ec2_key_name \
    --security-group-ids $ecs_ec2_sgr_id \
    --associate-public-ip-address \
    --user-data  file://ecs-ec2-userdata.txt \
    --tag-specifications `echo "ResourceType=instance,Tags=["$tagspec` | jq -r '.Instances[0].InstanceId')

aws ec2 associate-iam-instance-profile \
    --instance-id $ecs_ec2_id \
    --iam-instance-profile Name=$ecs_ec2_role_name

echo $ecs_ec2_id   
```
</details>

# Create IAM Role for TaskDefinition

<details>
<summary>Create IAM Role for TaskDefinition</summary>

## Create IAM Role for TaskDefinition
```shell
# Get ARN of AWS secret manager
secret_arn=$(aws secretsmanager describe-secret --secret-id $secret_name --query 'ARN' --output text)
echo $secret_arn
# Create ECS Role
ecs_task_role_arn=$(aws iam create-role \
    --role-name $ecs_task_role_name \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": ["sts:AssumeRole"]
        }]
    }' \
    --tags "$tags2" \
    --output text \
    --query 'Role.Arn')

cat <<EOF | tee ecs-task-role.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "`echo $secret_arn`",
        "`echo $secret_arn`*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name $ecs_task_role_name \
    --policy-name $ecs_task_policy_name \
    --policy-document file://ecs-task-role.json

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
    --role-name $ecs_task_role_name

ecs_task_role_arn=$(aws iam get-role \
    --role-name $ecs_task_role_name \
    --output text \
    --query 'Role.Arn')
```
</details>

# ECS Database

<details>
<summary>Create Task Definition for portgress database</summary>

## Create Task Definition for portgress database
```shell
# Create Task Definition for portgress database
cat <<EOF | tee database-definition.json
{
    "name": "`echo -n $ecs_task_database_name`",
    "image": "postgres",
    "essential": true,
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
        }
    ],
    "secrets" : [
        {
            "valueFrom" : "$secret_arn:POSTGRES_PASSWORD::",
            "name" : "POSTGRES_PASSWORD"
        }
    ]
}
EOF

ecs_database_task_definition=$(aws ecs register-task-definition \
    --family $database_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "512" \
    --memory "1024" \
    --tags "$tags" \
    --container-definitions "`jq -c . database-definition.json`" )

# Check ECS task definition created correctly
aws ecs list-task-definitions
```
</details>
<details>
<summary>Create Service for postgres database</summary>

## Create Service
```shell
# Database
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $database_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)

# Create Service
aws ecs create-service \
   --cluster $cluster_name \
   --service-name database-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"
```
</details>

# Create Backend

<details>
<summary>Create Task Definition for Backend</summary>

## Create Task Definition for Backend
```shell
cat <<EOF | tee backend-definition.json
{
    "name": "$backend_task_definition",
    "image": "$backend_image",
    "portMappings": [
        {
            "containerPort": 8080,
            "hostPort": 8080
        }
    ],
    "environment" : [
        {
            "name" : "POSTGRES_HOST",
            "value" : "10.0.4.247"
        },
        {
            "name" : "POSTGRES_DB",
            "value" : "example"
        },
        {
            "name" : "POSTGRES_PASSWORD",
            "value" : "`echo -n $sm_databasepsswd_arn`:POSTGRES_PASSWORD"
        }
    ]
}
EOF
ecs_backend_task_definition=$(aws ecs register-task-definition \
    --family $backend_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --tags "$tags" \
    --container-definitions "`jq -c . backend-definition.json`" )

# Check ECS task definition created correctly
aws ecs list-task-definitions
```
</details>
<details>
<summary>Create Service</summary>

## Create Service
```shell
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $backend_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
aws ecs create-service \
   --cluster $cluster_name \
   --service-name backend-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"
```
</details>

# Create Proxy

<details>
<summary>Create Task Definition for Nginx</summary>

## Create Task Definition for Nginx
```shell
cat <<EOF | tee proxy-definition.json
{
    "name": "$proxy_task_definition",
    "image": "$proxy_image",
    "portMappings": [
        {
            "containerPort": 80,
            "hostPort": 80
        }
    ],
    "environment" : [
        {
            "name" : "BACKEND_SERVER_ADDR",
            "value" : "10.0.3.31:8080"
        }
    ]
}
EOF
ecs_proxy_task_definition=$(aws ecs register-task-definition \
    --family $proxy_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --tags "$tags" \
    --container-definitions "`jq -c . proxy-definition.json`" )

# Check ECS task definition created correctly
aws ecs list-task-definitions
```
</details>
<details>
<summary>Create Service</summary>

## Create Service
```shell
# Nginx
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $proxy_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)
aws ecs create-service \
   --cluster $cluster_name \
   --service-name proxy-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"
```
</details>

# Clean

```shell
aws secretsmanager delete-secret --secret-id databaseSecret --force-delete-without-recovery
aws ec2 delete-key-pair --key-name aws-container-deploy-keypair
# delete EC2
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
# Delete Service
# Delete Task definition
aws ecs delete-cluster --cluster $cluster_name
```
