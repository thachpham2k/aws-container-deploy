# Create ECS

## Create ECS Cluster
```shell
aws ecs create-cluster \
        --cluster-name aws-container-deploy \
        --region ap-southeast-1 \
        --tags '[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]' 
```

## Check ECS Cluster create correctly
```shell
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
```

## Create EC2
```shell
# Create VPC and Enable dns-hostname feature in vpc
aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --region ap-southeast-1 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ecsvpc},{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'

vpc_id=$(aws ec2 create-vpc --cidr-block <your-cidr-block> --region <your-region> --output text --query 'Vpc.VpcId')

aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames '{"Value": true}'

# Create subnet
subnet_public_1=$(aws ec2 create-subnet --availability-zone <az-1> --cidr-block <public-subnet-1-cidr> \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_public_2=$(aws ec2 create-subnet --availability-zone <az-2> --cidr-block <public-subnet-2-cidr> \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_1=$(aws ec2 create-subnet --availability-zone <az-3> --cidr-block <private-subnet-1-cidr> \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

subnet_private_2=$(aws ec2 create-subnet --availability-zone <az-4> --cidr-block <private-subnet-2-cidr> \
    --vpc-id $vpc_id | jq -r '.Subnet.SubnetId')

gateway_id=$(aws ec2 create-internet-gateway --region <your-region> --output text --query 'InternetGateway.InternetGatewayId')

aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $gateway_id

public_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id | jq -r '.RouteTable.RouteTableId')

aws ec2 create-route --route-table-id $public_route_table_id \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $gateway_id

# Associate each public subnet with the public route table
aws ec2 associate-route-table --subnet-id $subnet_public_1 \
    --route-table-id $public_route_table_id

aws ec2 associate-route-table --subnet-id $subnet_public_2 \
    --route-table-id $public_route_table_id

# Create Keypair
aws ec2 create-key-pair --key-name <your-key-name> --region <your-region> --query 'KeyMaterial' --output text > <path-to-save>/<your-key-name>.pem

# Create Security Group
security_group_id=$(aws ec2 create-security-group \
    --group-name my-security-group \
    --description "My security group" \
    --vpc-id vpc-12345678 | jq -r '.GroupId')

aws ec2 authorize-security-group-ingress \
   --group-id $security_group_id \
   --protocol tcp \
   --port <ssh-port> \ # Cổng SSH nếu cần thiết
   --cidr <ip-range> # Phạm vi địa chỉ IP được phép truy cập (VD: 0.0.0.0/0)
   ecs_instance_id=$(aws ec2 run-instances \
    --image-id <your-ami-id> \
    --count 1 \
    --instance-type <your-instance-type> \
    --key-name <your-key-pair-name> \
    --security-group-ids $security_group_id | jq -r '.Instances[0].InstanceId')

# Get ECS AMI ID
[get ecs ami](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/retrieve-ecs-optimized_AMI.html)
ecs-ami=$(aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended --region ap-southeast-1 | jq -r '.Parameters[0].Value | fromjson.image_id')

# Create EC2
aws ec2 run-instances \
    --image-id <ami-id> \
    --instance-type <instance-type> \
    --key-name <your-key-name> \
    --subnet-id $subnet_public_1
# Thiếu ÉCS instance role với Metadata

aws ecs register-container-instance --cluster <your-cluster-name> --instance-id <your-instance-id>

aws ecs create-service \
   --cluster my-cluster \
   --service-name my-service \ 
   --task-definition $ecs_task_definition \ 
   --desired-count 1
```









## Delete ECS Cluster
```shell
aws ecs delete-cluster --cluster awsContainerDeploy
```
