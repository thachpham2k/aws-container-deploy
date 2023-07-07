**Deploy Container into ECS and using ALB to redirect connection, and RDS as Database Server**
===

<details>
<summary>Project init</summary>

```shell
sudo apt update -y
sudo apt install jq awscli tee -y
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
# project
project=aws-container-deploy-2-ecs
# global architect
region=ap-southeast-1
az_01=ap-southeast-1a
az_02=ap-southeast-1b
# tags
tags='[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]'
tags2='[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
tagspec='{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
# SecretManager
database_psswd=db-1357
# ECS
cluster_name=$project-cluster
backend_task_definition=backend-td
proxy_task_definition=nginx-td
database_task_definition=database-td
backend_image=914706199417.dkr.ecr.ap-southeast-1.amazonaws.com/backend-image:latest
proxy_image=914706199417.dkr.ecr.ap-southeast-1.amazonaws.com/proxy-image:latest
# network
vpc_cidr=10.0.0.0/16
pubsubnet1_cidr=10.0.0.0/20
pubsubnet2_cidr=10.0.16.0/20
prisubnet1_cidr=10.0.128.0/20
prisubnet2_cidr=10.0.144.0/20
# db-password
db_password=db-abc-123
```

</details>

<details>
<summary>Create Network</summary>

## Create VPC
```shell
# Create VPC and Enable dns-hostname feature in vpc
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo 'ResourceType=vpc,Tags=[{Key=Name,Value=Deploy2ECS-vpc},'$tagspec` \
    --output text \
    --query 'Vpc.VpcId')

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
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value=Deploy2ECS-publicsubnet-'$az_01'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $pubsubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value=Deploy2ECS-publicsubnet-'$az_02'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet \
    --availability-zone $az_01 \
    --cidr-block $prisubnet1_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value=Deploy2ECS-privatesubnet-'$az_01'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet \
    --availability-zone $az_02 \
    --cidr-block $prisubnet2_cidr \
    --tag-specifications `echo 'ResourceType=subnet,Tags=[{Key=Name,Value=Deploy2ECS-privatesubnet-'$az_02'},'$tagspec` \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')
```
## Create Internet Gateway
```shell
# Create Internet Gateway
gateway_id=$(aws ec2 create-internet-gateway \
    --region $region \
    --tag-specifications `echo 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=Deploy2ECS-igw},'$tagspec` \
    --output text \
    --query 'InternetGateway.InternetGatewayId')

aws ec2 attach-internet-gateway \
    --vpc-id $vpc_id \
    --internet-gateway-id $gateway_id
```
## Create Routetable and Routing
```shell
# Create Route table
public_route_table_id=$(aws ec2 create-route-table \
    --tag-specifications `echo 'ResourceType=route-table,Tags=[{Key=Name,Value=Deploy2ECS-rtb},'$tagspec` \
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

</details>

<details>
<summary>Create RDS</summary>

# Create Subnet Group
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
    --master-user-password $db_password \
    --storage-type gp2 \
    --no-enable-performance-insights \
    --availability-zone $az_01 \
    --db-subnet-group-name $subnet_group_name \
    --vpc-security-group-ids $rds_sgr_id \
    --backup-retention-period 0 \
    --tags "$tags2"

aws rds wait db-instance-available \
    --db-instance-identifier $db_name

rds_address=$(aws rds describe-db-instances \
    --db-instance-identifier $db_name \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)
```

</details>

<details>
<summary>Create ECS</summary>

</details>

<details>
<summary>Create ALB</summary>

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
    --targets Id=$ec2_instance_id

alb_listener_arn=$(aws elbv2 create-listener \
  --load-balancer-arn $alb_arn \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$alb_tgr_arn \
  --query 'Listeners[0].ListenerArn' \
  --output text)

aws elbv2 describe-target-health --target-group-arn $alb_tgr_arn
```

</details>

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

<details>
<summary>Clean</summary>

```shell
aws elbv2 delete-listener --listener-arn $alb_listener_arn
aws elbv2 delete-target-group --target-group-arn $alb_tgr_arn
aws elbv2 delete-load-balancer --load-balancer-arn $alb_arn
aws ec2 delete-security-group --group-id $alb_sgr_id
aws ec2 terminate-instances --instance-ids $ec2_instance_id
aws ec2 delete-key-pair --key-name $key_name
rm -f $key_name
aws rds delete-db-instance --db-instance-identifier $db_name --skip-final-snapshot
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
```

</details>