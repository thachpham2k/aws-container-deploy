**Deploy Container into ECS and using ALB to redirect connection, and RDS as Database Server**
===

# Project init

<details>
<summary>Project init</summary>

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

## Shell Variable
```shell
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
# SecretManager
secret_name=$project-sm
database_psswd=$(cat db_password)
# ECS
cluster_name=$project-cluster
backend_task_definition=$project-backend-td
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
backend_image=$aws_account_id.dkr.ecr.$region.amazonaws.com/backend-container:latest
# network
vpc_cidr=10.1.0.0/16
pubsubnet1_cidr=10.1.0.0/20
pubsubnet2_cidr=10.1.16.0/20
prisubnet1_cidr=10.1.128.0/20
prisubnet2_cidr=10.1.144.0/20
```

</details>

# Create Network

<details>
<summary>Create Network</summary>

## Create VPC
```shell
# Create VPC and Enable dns-hostname feature in vpc
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo 'ResourceType=vpc,Tags=[{Key=Name,Value='$project2'-vpc},'$tagspec` \
    --output text \
    --query 'Vpc.VpcId')

echo $vpc_id

aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'
```
## Create Subnet
```shell
# Create subnet
subnet_public_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $pubsubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$project2'-publicsubnet-'$az_01'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$project2'-publicsubnet-'$az_02'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$project2'-privatesubnet-'$az_01'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value='$project2'-privatesubnet-'$az_02'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

echo $subnet_public_1
echo $subnet_public_2
echo $subnet_private_1
echo $subnet_private_2
```
## Create Internet Gateway
```shell
# Create Internet Gateway
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --tag-specifications `echo 'ResourceType=internet-gateway,Tags=[{Key=Name,Value='$project2'-igw},'$tagspec` \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

echo $gateway_id

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id
```
## Create Routetable and Routing
```shell
# Create Route table
public_route_table_id=$(aws ec2 create-route-table \
    --tag-specifications `echo 'ResourceType=route-table,Tags=[{Key=Name,Value='$project2'-rtb},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.RouteTable.RouteTableId')

echo $public_route_table_id

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

</details>

# Create RDS

<details>
<summary>Create RDS</summary>

## Create Subnet Group
```shell
# Create Subnet group
subnet_group_name=$(echo $project'-subnet-group')
aws rds create-db-subnet-group \
    --db-subnet-group-name $subnet_group_name \
    --db-subnet-group-description "Subnet Group for Postgres RDS" \
    --subnet-ids $subnet_private_1 $subnet_private_2 \
    --tags "$tags2"
```
## Create Security group
```shell
# Create Security Group
rds_sgr_id=$(aws ec2 create-security-group \
    --group-name `echo $project`-rds-sgr \
    --description "Security group for RDS" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=['$tagspec` \
    --vpc-id $vpc_id | jq -r '.GroupId')

echo $rds_sgr_id

aws ec2 authorize-security-group-ingress \
    --group-id $rds_sgr_id \
    --protocol tcp \
    --port 5432 \
    --cidr 0.0.0.0/0
```
## Create RDS
```shell
db_name=$(echo $project'-rds')
aws rds create-db-instance \
    --db-instance-identifier $db_name \
    --engine postgres \
    --db-name example \
    --db-instance-class db.t3.micro \
    --allocated-storage 20 \
    --master-username postgres \
    --master-user-password $database_psswd \
    --storage-type gp2 \
    --no-enable-performance-insights \
    --availability-zone $az_01 \
    --db-subnet-group-name $subnet_group_name \
    --vpc-security-group-ids $rds_sgr_id \
    --backup-retention-period 0 \
    --tags "$tags2"

aws rds wait db-instance-available \
    --db-instance-identifier $db_name
```

</details>

# Create Secret Manager

<details>
<summary>Create Secret Manager</summary>

## Get RDS information
```shell
rds_address=$(aws rds describe-db-instances \
    --db-instance-identifier $db_name \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

echo $rds_address
```

## Create Secret Manager
```shell
aws secretsmanager create-secret \
    --name $secret_name \
    --description "To save database information" \
    --tags "$tags2" \
    --secret-string `echo "{\"user\":\"root\",\"POSTGRES_HOST\":\"$rds_address\",\"POSTGRES_DB\":\"example\",\"POSTGRES_PASSWORD\":\"$database_psswd\"}"`
```

</details>

# Create ECS

<details>
<summary>Create ECS</summary>

## Create ECS Cluster
```shell
aws ecs create-cluster \
    --cluster-name $cluster_name \
    --region $region \
    --tags "$tags"

# Check ECS Cluster created correctly
aws ecs list-clusters
```

## Create EC2
```shell
key_name=$(echo $project-keypair)
# Create Keypair
aws ec2 create-key-pair \
    --key-name $key_name \
    --region $region \
    --tag-specifications `echo 'ResourceType=key-pair,Tags=['$tagspec` \
    --query 'KeyMaterial' \
    --output text > ./$key_name.pem

ecs_sgr_name=$(echo $project-ecs-sgr)
# Create Security Group
security_group_id=$(aws ec2 create-security-group \
    --group-name $ecs_sgr_name \
    --description "Security group for EC2 in ECS" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=['$tagspec` \
    --vpc-id $vpc_id | jq -r '.GroupId')

echo $security_group_id

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

ecs_role_name=$(echo $project-ecs-ec2-role)
# Create EC2 Role
aws iam create-role \
    --role-name $ecs_role_name \
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
    --role-name $ecs_role_name

aws iam attach-role-policy \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore \
    --role-name $ecs_role_name

aws iam create-instance-profile \
    --instance-profile-name $ecs_role_name

aws iam add-role-to-instance-profile \
    --instance-profile-name $ecs_role_name \
    --role-name $ecs_role_name

# Get ECS AMI ID
[get ecs ami](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html)
ecs_ami=$(aws ssm get-parameters \
    --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended \
    --region $region | jq -r '.Parameters[0].Value | fromjson.image_id')

echo $ecs_ami

# Create EC2
cat <<EOF | tee ecs-userdata.txt
#!/bin/bash
echo ECS_CLUSTER=`echo -n $cluster_name` >> /etc/ecs/ecs.config
EOF

ecs_instance_id=$(aws ec2 run-instances \
    --image-id $ecs_ami \
    --count 1 \
    --instance-type t3.medium \
    --subnet-id $subnet_public_1 \
    --key-name $key_name \
    --security-group-ids $security_group_id \
    --associate-public-ip-address \
    --user-data  file://ecs-userdata.txt \
    --tag-specifications `echo "ResourceType=instance,Tags=["$tagspec` | jq -r '.Instances[0].InstanceId')

echo $ecs_instance_id

aws ec2 associate-iam-instance-profile \
    --instance-id $ecs_instance_id \
    --iam-instance-profile Name=$ecs_role_name
```

## Create Task Definition for Backend
```shell
# Get ARN of AWS secret manager
sm_databasepsswd_arn=$(aws secretsmanager describe-secret --secret-id $secret_name --query 'ARN' --output text)

echo $sm_databasepsswd_arn
# Create Task Definition role
ecs_task_role_name=$(echo $project-ecs-task-role)
# Create EC2 Role
aws iam create-role \
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
    --query 'Role.Arn' \
    --output text

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
        "`echo $sm_databasepsswd_arn`",
        "`echo $sm_databasepsswd_arn`*"
      ]
    }
  ]
}
EOF
aws iam put-role-policy \
    --role-name $ecs_task_role_name \
    --policy-name ecs_task_policy \
    --policy-document file://ecs-task-role.json

ecs_task_role_arn=$(aws iam get-role \
    --role-name $ecs_task_role_name \
    --output text \
    --query 'Role.Arn')

# Content of task-definition
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
    "secrets" : [
        {
            "valueFrom" : "$sm_databasepsswd_arn:POSTGRES_HOST::",
            "name" : "POSTGRES_HOST"
        },
        {
            "valueFrom" : "$sm_databasepsswd_arn:POSTGRES_DB::",
            "name" : "POSTGRES_DB"
        },
        {
            "valueFrom" : "$sm_databasepsswd_arn:POSTGRES_PASSWORD::",
            "name" : "POSTGRES_PASSWORD"
        }
    ]
}
EOF
# Create task-definition
ecs_backend_task_definition=$(aws ecs register-task-definition \
    --family $backend_task_definition \
    --network-mode awsvpc \
    --requires-compatibilities EC2 \
    --cpu "256" \
    --memory "512" \
    --execution-role-arn $ecs_task_role_arn \
    --tags "$tags" \
    --container-definitions "`jq -c . backend-definition.json`" )

# Check ECS task definition created correctly
aws ecs list-task-definitions
```

## Create Service
```shell
# Backend
ecs_task_definition=$(aws ecs describe-task-definition \
    --task-definition $backend_task_definition \
    --query "taskDefinition.taskDefinitionArn" \
    --output text)

echo $ecs_task_definition

aws ecs create-service \
   --cluster $cluster_name \
   --service-name backend2-service \
   --task-definition $ecs_task_definition \
   --desired-count 1 \
   --network-configuration "awsvpcConfiguration={subnets=[$subnet_public_1],securityGroups=[$security_group_id]}"
```

</details>

# Create ALB

<details>
<summary>Create ALB</summary>

## Prepare
```shell
# Create security group
alb_sgr_id=$(aws ec2 create-security-group \
    --group-name `echo $project'-alb-sgr'` \
    --description "Security group for ALB" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=['$tagspec` \
    --vpc-id $vpc_id | jq -r '.GroupId')

aws ec2 authorize-security-group-ingress \
   --group-id $alb_sgr_id \
   --protocol tcp \
   --port 22 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $alb_sgr_id \
   --protocol tcp \
   --port 80 \
   --cidr 0.0.0.0/0
```
## Create ALB
```shell
# Create ALB
alb_name=$(echo $project-alb)
alb_arn=$(aws elbv2 create-load-balancer \
    --name $alb_name  \
    --subnets $subnet_public_1 $subnet_public_2 \
    --security-groups $alb_sgr_id \
    --tags "$tags2" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
echo $alb_arn

alb_tgr_name=$(echo $project-tgr)
alb_tgr_arn=$(aws elbv2 create-target-group \
    --name $alb_tgr_name \
    --protocol HTTP \
    --port 8080 \
    --vpc-id $vpc_id \
    --tags "$tags2" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
echo $alb_tgr_arn

aws elbv2 register-targets \
    --target-group-arn $alb_tgr_arn  \
    --targets Id=$ecs_instance_id

alb_listener_arn=$(aws elbv2 create-listener \
  --load-balancer-arn $alb_arn \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$alb_tgr_arn \
  --query 'Listeners[0].ListenerArn' \
  --output text)

aws elbv2 describe-target-health --target-group-arn $alb_tgr_arn
```

## Update the ECS service to use your ALB
```shell
aws elbv2 modify-target-group-attributes \
    --target-group-arn $alb_tgr_arn \
    --attributes '[{"Key":"target-type","Value":"ip"}'
aws ecs update-service --cluster $cluster_name \
    --service backend2-service \
    --desired-count 1 \
    --load-balancers targetGroupArn=$alb_tgr_arn,containerName=$backend_task_definition,containerPort=8080
```

</details>

# Check correct

<details>
<summary>Check correct</summary>

```shell
aws elbv2 describe-load-balancers \
    --load-balancer-arns $alb_arn \
    --query 'LoadBalancers[0].DNSName' \
    --output text
```

![Success](access-website-with-alb-dns-success.png)

</details>

# Clean

<details>
<summary>Clean</summary>

```shell
aws elbv2 delete-listener --listener-arn $alb_listener_arn
aws elbv2 delete-target-group --target-group-arn $alb_tgr_arn
aws elbv2 delete-load-balancer --load-balancer-arn $alb_arn
aws ec2 delete-security-group --group-id $alb_sgr_id
aws ec2 terminate-instances --instance-ids $ecs_instance_id
aws ec2 delete-key-pair --key-name $key_name
rm -f $key_name
aws rds delete-db-instance --db-instance-identifier $db_name --skip-final-snapshot
aws rds wait db-instance-deleted --db-instance-identifier $db_name
aws ec2 delete-security-group --group-id $rds_sgr_id
aws rds delete-db-subnet-group --db-subnet-group-name $subnet_group_name
aws ec2 delete-security-group --group-id $security_group_id
aws ec2 delete-subnet --subnet-id $subnet_public_1
aws ec2 delete-subnet --subnet-id $subnet_public_2
aws ec2 delete-subnet --subnet-id $subnet_private_1
aws ec2 delete-subnet --subnet-id $subnet_private_2
aws ec2 delete-route-table --route-table-id $public_route_table_id
aws ec2 detach-internet-gateway --internet-gateway-id $gateway_id --vpc-id $vpc_id
aws ec2 delete-internet-gateway --internet-gateway-id $gateway_id
aws ec2 delete-vpc --vpc-id $vpc_id

aws secretsmanager delete-secret \
    --secret-id aws-container-deploy-2-ecs-sm \
    --force-delete-without-recovery
```

</details>