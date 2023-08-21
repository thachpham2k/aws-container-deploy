**Deploy Container into EKS**
===

This project is in progress

## Prepare for project
<details>
<summary>
<b>Prepare for project</b>

- Install CLI
    - Install AWS CLI
    - Install kubectl CLI
    - Install eksctl CLI
- Shell Variable
</summary><br>

<details>
<summary>Install AWS CLI</summary>

```shell
# sudo apt install awscli -y
# aws --version
# aws configure
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update # hoặc sudo ./aws/install nếu gặp lỗi
aws --version
```
</details>
<details>
<summary>Install kubectl CLI</summary>
<a href="https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html">Installing or updating kubectl</a>

```shell
kubectl version --short --client
cd ~
mkdir kuberctl
cd kuberctl
# Download the Package
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.1/2023-04-19/bin/linux/amd64/kubectl
# Provide execute permissions
chmod +x ./kubectl
# Set the Path by copying to user Home Directory
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
# Verify the kubectl version
kubectl version --short --client
```
</details>
<details>
<summary>
Install eksctl CLI

</summary>

<a href="https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html">Installing or updating eksctl</a>
<br>
<a href="https://github.com/eksctl-io/eksctl/blob/main/README.md#installation">Eksctl</a>

```shell
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
# Download the Package (curl --silent --location)
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
# extract
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv -v /tmp/eksctl /usr/local/bin
eksctl info
```
</details>
<details>
<summary>Shell Variable</summary>

## Shell Variable
```shell
# project
project=eks-deploy
project2=Deploy2EKS
# global architect
region=ap-southeast-1
az_01=ap-southeast-1a
az_02=ap-southeast-1b
az_03=ap-southeast-1c
# tags
tags='[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]'
tags2='[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
tagspec='{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}]'
# Identity
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)
# network
vpc_cidr=10.1.0.0/16
pubsubnet1_cidr=10.1.0.0/20
pubsubnet2_cidr=10.1.16.0/20
pubsubnet3_cidr=10.1.32.0/20
prisubnet1_cidr=10.1.128.0/20
prisubnet2_cidr=10.1.144.0/20
prisubnet3_cidr=10.1.160.0/20
# database
db_name="database"
db_password=$(cat db_password | base64)
```
</details>
</details>

## Create Networking

<details>
<summary>
<b>Networking</b>
<br>

- VPC
- Subnet
- internetGateway
- RouteTable
- SecurityGroup
</summary>

<details>
<summary>
Shell Variable
</summary>

```shell
vpc_name=$project-vpc
pubsubnet1_name=$project2-pubsubnet-$az_01
pubsubnet2_name=$project2-pubsubnet-$az_02
pubsubnet3_name=$project2-pubsubnet-$az_03
prisubnet1_name=$project2-prisubnet-$az_01
prisubnet2_name=$project2-prisubnet-$az_02
prisubnet3_name=$project2-prisubnet-$az_03
igw_name=$project2-igw
rtb_name=$project2-rtb
sgr_name=$project2-sgr
```
</details>
<details>
<summary>
VPC
</summary>

```shell
# Create VPC
vpc_id=$(aws ec2 create-vpc \
    --cidr-block $vpc_cidr \
    --region $region \
    --tag-specifications `echo 'ResourceType=vpc,Tags=[{Key=Name,Value='$vpc_name'},'$tagspec` \
    --output text \
    --query 'Vpc.VpcId')

# Enable dns-hostname feature in vpc
aws ec2 modify-vpc-attribute \
    --vpc-id $vpc_id \
    --enable-dns-hostnames '{"Value": true}'

echo $vpc_id
```
</details>
<details>
<summary>
Subnet
</summary>

```shell
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
<summary>
internetGateway
</summary>

```shell
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
<summary>
RouteTable
</summary>

```shell
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
<details>
<summary>
SecurityGroup
</summary>

```shell
# Create Security Group
sgr_id=$(aws ec2 create-security-group \
    --group-name $sgr_name \
    --description "Security group for EKS" \
    --tag-specifications `echo 'ResourceType=security-group,Tags=['$tagspec` \
    --vpc-id $vpc_id | jq -r '.GroupId')

aws ec2 authorize-security-group-ingress \
   --group-id $sgr_id \
   --protocol tcp \
   --port 80 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $sgr_id \
   --protocol tcp \
   --port 22 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $sgr_id \
   --protocol tcp \
   --port 5432 \
   --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
   --group-id $sgr_id \
   --protocol tcp \
   --port 8080 \
   --cidr 0.0.0.0/0

echo $sgr_id
```
</details>
</details>

## Create SSH keypair

<details>
<summary>
<b>Create SSH keypair</b>
</summary>

```shell
keypair_name=$project-keypair
# Create Keypair
aws ec2 create-key-pair \
    --key-name $keypair_name \
    --region $region \
    --tag-specifications `echo 'ResourceType=key-pair,Tags=['$tagspec` \
    --query 'KeyMaterial' \
    --output text > ./$keypair_name.pem
```
</details>

## Create IAM

<details>
<summary>Create IAM for EKS</summary>

```shell
iam_role_name=$project-role
iam_profile_name=$project-profile
# Create EKS Role
aws iam create-role \
  --role-name $iam_role_name \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": ["eks.amazonaws.com", "ec2.amazonaws.com"]
      },
      "Action": ["sts:AssumeRole"]
    }]
  }' \
    --tags "$tags2"
    
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
  --role-name $iam_role_name

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
  --role-name $iam_role_name

aws iam create-instance-profile \
  --instance-profile-name $iam_profile_name

aws iam add-role-to-instance-profile \
  --instance-profile-name $iam_profile_name \
  --role-name $iam_role_name

iam_role_arn=$(aws iam get-role \
  --role-name $iam_role_name \
  --output text \
  --query 'Role.Arn')

iam_profile_arn=$(aws iam get-instance-profile \
  --instance-profile-name $iam_profile_name \
  --output text \
  --query 'InstanceProfile.Arn')

echo $iam_role_arn
echo $iam_profile_arn
```
</details>

## Create ECR

[Create ECR for Backend](../ECR/README.md)

```shell
eks_task_backend_image=$aws_account_id.dkr.ecr.$region.amazonaws.com/container-image:latest
```

## Create Cluster

<details>
<summary>
<b>Create EKS Cluster using eksctl</b>
<br>

Sử dụng giao diện cần:
- IAM (IAM Role for EKS-Cluster) [link](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html#create-service-role)
- Tags
- VPC, Subnet, SecurityGroup, Access(PublicOrPrivate)
- Logging
- AddOns and ConfigAddOns
</summary>

```shell
# shell variable
eks_cluster_name=$project-cluster
eks_nodegroup_name=$project-ng-public
```
<details>
<summary>Using manifest</summary>
<a href="https://eksctl.io/">reference</a>

```shell
cat <<EOF | tee manifest/cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $eks_cluster_name
  region: $region
  version: "1.27"

# availabilityZones:
#   - $az_01
#   - $az_02

vpc:
  subnets:
    private:
      private-01: { id: $subnet_private_1 }
      private-02: { id: $subnet_private_2 }
    public:
      public-01: { id: $subnet_public_1 }
      public-02: { id: $subnet_public_2 }
  sharedNodeSecurityGroup: $sgr_id
  manageSharedNodeSecurityGroupRules: false
  nat:
    gateway: Single
  clusterEndpoints:
    publicAccess: true

iam:
  withOIDC: true
  vpcResourceControllerPolicy: true

nodeGroups:
  - name: $eks_nodegroup_name
    labels: { role: workers }
    instanceType: t3.medium
    desiredCapacity: 1
    minSize: 1 
    maxSize: 2 
    volumeSize: 20 
    subnets:
      - public-01
    ssh:
      # enableSsm: true
      publicKeyName: $keypair_name
    iam:
      instanceProfileARN: "$iam_profile_arn"
      instanceRoleARN: "$iam_role_arn"
      # withAddonPolicies:
      #   albIngress: true
      #   imageBuilder: true
      #   # autoScaler: true
      #   # externalDNS: true
      #   certManager: true
      #   # appMesh: true
      #   # appMeshPreview: true
      #   ebs: true
      #   # fsx: true
      #   # efs: true
      #   awsLoadBalancerController: true
      #   # xRay: true
      #   cloudWatch: true 
EOF

# Create Cluster
eksctl create cluster -f manifest/cluster.yaml --version=1.27


# Get List of cluster
eksctl get cluster

# Delete Cluster
eksctl delete cluster -f manifest/cluster.yaml
```
</details>
<details>
<summary>Using CLI</summary>

```shell
# Create Cluster
eksctl create cluster \
  --name=$eks_cluster_name \
  --region=$region \
  --zones=$az_01,$az_02 \
  --vpc-private-subnets=$subnet_private_1,$subnet_private_2 \
  --vpc-public-subnets=$subnet_public_1,$subnet_public_2 \
  --vpc-nat-mode=Single \
  --without-nodegroup \
  --version=1.27

# Get List of clusters
eksctl get cluster
# Create & Associate IAM OIDC Provider for our EKS Cluster
eksctl utils associate-iam-oidc-provider \
    --region region-code \
    --cluster $eks_cluster_name \
    --approve

# Create Public Node Group   
eksctl create nodegroup \
  --cluster=$eks_cluster_name \
  --region=$region \
  --name=$eks_nodegroup_name \
  --node-type=t3.medium \
  --nodes=1 \
  --nodes-min=1 \
  --nodes-max=2 \
  --node-volume-size=20 \
  --ssh-access \
  --ssh-public-key=$keypair_name \
  --managed \
  --asg-access \
  --external-dns-access \
  --full-ecr-access \
  --alb-ingress-access
```
</details>
</details>

## Create Database

<details>
<summary>
<b>Create Database</b>
</summary>

```shell
eks_secret_db_name=$project-eks-secret-db
eks_sevice_db_name=$project-eks-svc-db
cat <<EOF | tee manifest/mysql.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: $eks_secret_db_name
type: Opaque
data: 
  db-password: $db_password
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: 
  name: ebs-postgres-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-postgres-sc
  resources:
    requests:
      storage: 4Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-dbcreation-script
data:
  postgres.sql: |-
    DROP DATABASE IF EXISTS $db_name;
    CREATE DATABASE $db_name;
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:latest
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: $eks_secret_db_name
                  key: db-password
          ports:
            - containerPort: 5432
              name: postgres
          volumeMounts:
            - name: postgres-persistent-storage
              mountPath: /var/lib/postgres
            - name: postgres-dbcreation-script
              mountPath: /docker-entrypoint-initdb.d                                      
      volumes:
        - name: postgres-persistent-storage
          persistentVolumeClaim:
            claimName: ebs-postgres-pvc
        - name: postgres-dbcreation-script
          configMap:
            name: postgres-dbcreation-script
---
apiVersion: v1
kind: Service
metadata:
  name: $eks_sevice_db_name
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
  clusterIP: None
---
EOF
```
</details>

## Create Backend

<details>
<summary>
<b>Create Backend App</b>
</summary>

```shell
cat <<EOF | tee manifest/mysql.yaml
---
apiVersion: apps/v1
kind: Deployment 
metadata:
  name: backendapp
  labels:
    app: backend-restapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-restapp
  template:  
    metadata:
      labels: 
        app: backend-restapp
    spec:
      containers:
        - name: backend-restapp
          image: $ecr???
          ports: 
            - containerPort: 8080           
          env:
            - name: POSTGRES_HOST
              value: "$eks_sevice_db_name"                      
            - name: POSTGRES_DB
              value: "$db_name"            
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-db-password
                  key: db-password      
---
apiVersion: v1
kind: Service
metadata:
  name: backend-restapp-service
  labels: 
    app: backend-restapp
spec:
  type: NodePort
  selector:
    app: backend-restapp
  ports: 
    - port: 8080
      targetPort: 8080
      nodePort: 31231
---
EOF
```
</details>

## Create Loadbalancer

<details>
<summary>
<b>Create ALB</b>
</summary>

```shell
cat <<EOF | tee manifest/mysql.yaml

EOF
```
</details>

## Clean

<details>
<summary>
<b>Clean</b>
</summary>

```shell
```
</details>