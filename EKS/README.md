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
- Install tools
- Shell Variable
</summary><br>

<details>
<summary>Install CLI</summary>

<a href="https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html">Installing or updating kubectl</a>
<br>
<a href="https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html">Installing or updating eksctl</a>
<br>
<a href="https://github.com/eksctl-io/eksctl/blob/main/README.md#installation">Eksctl</a>

```shell
# awscliv1
# sudo apt install awscli -y

# awscliv2
source ../script/install_awscliv2.sh

aws --version

# kubectl
source ../script/install_kubectl.sh

kubectl version --short --client

# eksctl
## for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
source ../script/install_eksctl.sh

eksctl info
```
</details>
<details>
<summary>Install tools</summary>

## Install tools
```shell
sudo apt install jq -y
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
tags='[{"Key":"purpose", "Value":"test"}, {"Key":"project", "Value":"aws-container-deploy"}, {"Key":"author", "Value":"pthach"}]'
tags2='[{"key":"purpose", "value":"test"}, {"key":"project", "value":"aws-container-deploy"}, {"key":"author", "value":"pthach"}]'
tagspec='{Key=purpose,Value=test},{Key=project,Value=aws-container-deploy},{Key=author,Value=pthach}'
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
VPC, Subnet, IGW, RTB
</summary>

```shell
# Name Tags
vpc_name=$project-vpc
pubsubnet1_name=$project2-pubsubnet-$az_01
pubsubnet2_name=$project2-pubsubnet-$az_02
pubsubnet3_name=$project2-pubsubnet-$az_03
prisubnet1_name=$project2-prisubnet-$az_01
prisubnet2_name=$project2-prisubnet-$az_02
prisubnet3_name=$project2-prisubnet-$az_03
igw_name=$project2-igw
rtb_name=$project2-rtb

source ../script/create_network_3az.sh

echo $vpc_id
echo $subnet_public_1
echo $subnet_public_2
echo $subnet_public_3
echo $subnet_private_1
echo $subnet_private_2
echo $subnet_private_3
echo $gateway_id
echo $rtb_public_id
```
</details>
<details>
<summary>
SecurityGroup
</summary>

```shell
# Name Tags
sgr_name=$project2-sgr
sgr_rules=( 80 22 5432 8080 )

source ../script/create_network_sgr.sh

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
keypair_dst="../EKS/$keypair_name.pem"
# Create Keypair
source ../script/create_ec2_keypair.sh
```
</details>

## Create IAM

<details>
<summary>Create IAM for EKS</summary>

```shell
iam_role_name=$project-role
iam_profile_name=$project-profile
iam_principal_service='"eks.amazonaws.com","ec2.amazonaws.com"'
iam_default_policies=( arn:aws:iam::aws:policy/AmazonEKSClusterPolicy arn:aws:iam::aws:policy/AmazonEC2FullAccess arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds )
iam_custom_policy_name=
iam_custom_policy_file=

source ../script/create_iam_role_n_instance_profile.sh

echo $iam_role_arn
echo $iam_profile_arn
```
</details>

## Create ECR

[Create ECR for Backend](../ECR/README.md)

<details>
<summary>Create ECR Repository</summary>

```shell
repo_name='container-image'
src_dir='../src/backend'

source ../script/create_ecr.sh

echo $ecr_image_uri

eks_task_backend_image=$ecr_image_uri
```
</details>

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

# Connect to EKS
aws eks update-kubeconfig --region $region --name $eks_cluster_name

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
cat <<EOF | tee manifest/backend.yaml
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
          image: $eks_task_backend_image
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
                  name: $eks_secret_db_name
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
cat <<EOF | tee manifest/alb.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-alb-service
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080       # The port your application is listening on

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: my-alb-ingress          # Name of the ALB Ingress resource 
spec:
  rules:
    - http:
        paths:
          - pathType: Prefix     # Path type can be either "Prefix" or "Exact"
            path:/               # The URL path that will route traffic to your service/app   
            backend:
              serviceName : my-alb-service   # Name of the service defined above in 'metadata.name'
              servicePort : 80                # Port number defined in 'spec.ports.port'
EOF
```
</details>

## Clean

<details>
<summary>
<b>Clean</b>
</summary>

```shell
kubectl delete -f manifest/backend.yaml
kubectl delete -f manifest/mysql.yaml 
eksctl delete cluster -f manifest/cluster.yaml

# ECR
source ../script/delete_ecr.sh
# IAM
source ../script/delete_iam_role_n_instance_profile.sh
# Keypair
source ../script/delete_ec2_keypair.sh
# Network
source ../script/delete_network_sgr.sh 
source ../script/delete_network_3az.sh 
```
</details>