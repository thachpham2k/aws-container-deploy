# Create ECS

## Create ECS Cluster
```shell
aws ecs create-cluster \
    --cluster-name aws-container-deploy \
    --region ap-southeast-1 \
    --tags '[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]' 

# Check ECS Cluster created correctly
aws ecs list-clusters
```

## Create Task Definition
```shell
ecs_task_definition=$(aws ecs register-task-definition \
    --family aws-container-deploy-task-definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --container-definitions '[
        {
            "name": "aws-container-deploy-taskdefinition",
            "image": "914706199417.dkr.ecr.ap-southeast-1.amazonaws.com/container-image:latest",
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

## Create EC2
```shell
region=ap-southeast-1
az_01=ap-southeast-1b
az_02=ap-southeast-1a
tagspec='ResourceType=vpc,Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
subnet_tagspec='ResourceType=subnet,Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
vpc_cidr=10.0.0.0/16
pubsubnet1_cidr=10.0.0.0/20
pubsubnet2_cidr=10.0.16.0/20
prisubnet1_cidr=10.0.128.0/20
prisubnet2_cidr=10.0.144.0/20
role_name=aws-container-deploy-role
key_name=aws-container-deploy-keypair
sgr_name=aws-container-deploy-sgr

# Create VPC and Enable dns-hostname feature in vpc
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications $tagspec\
    --output text \
    --query 'Vpc.VpcId')

aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'

# Create subnet
subnet_public_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $pubsubnet1_cidr \
    --tag-specifications $subnet_tagspec \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications $subnet_tagspec \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications $subnet_tagspec \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications $subnet_tagspec \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

# Create Internet Gateway
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id

public_route_table_id=$(aws ec2 create-route-table \
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

# Create Keypair
aws ec2 create-key-pair \
    --key-name $key_name \
    --region $region \
    --query 'KeyMaterial' \
    --output text > ./$key_name.pem

# Create Security Group
security_group_id=$(aws ec2 create-security-group \
    --group-name $sgr_name \
    --description "Security group for EC2 in ECS" \
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

# Get ECS AMI ID
[get ecs ami](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html)
ecs_ami=$(aws ssm get-parameters \
    --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
    --region $region | jq -r '.Parameters[0].Value | fromjson.image_id')

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
    }'

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
echo ECS_CLUSTER=aws-container-deploy >> /etc/ecs/ecs.config' | jq -r '.Instances[0].InstanceId')

aws ec2 associate-iam-instance-profile \
    --instance-id $ecs_instance_id \
    --iam-instance-profile Name=$role_name

# aws ecs register-container-instance --cluster aws-container-deploy --instance-id $ecs_instance_id
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition aws-container-deploy-task-definition \
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
