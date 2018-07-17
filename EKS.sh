#!/bin/bash
echo "This will create a working EKS Cluster"

echo "Creating Service role for EKS"

aws cloudformation create-stack \
  --stack-name eks-service-role \
  --template-body file://eks-service-role.yaml \
  --capabilities CAPABILITY_NAMED_IAM
echo "Waiting for Service role creation"

aws cloudformation wait stack-create-complete --stack-name eks-service-role

echo "Download and Check for Installation of Heptio Auth"

if command -v heptio-authenticator-aws; then
    echo "heptio-authenticator-aws is already installed"; else
    mkdir "./aws" && cd "./aws" || exit 1
    curl -o heptio-authenticator-aws "https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/heptio-authenticator-aws"
    chmod +x ./heptio-authenticator-aws
    cp ./heptio-authenticator-aws /usr/local/bin/
    echo "export PATH=$HOME/bin:$PATH" >> ~/.zshrc
    rm -rf "./aws"
fi

echo "Creating VPC using cloudformation template"

aws cloudformation create-stack \
  --stack-name EKS-Test \
  --template-body file://eks-vpc.yaml \
  --region us-east-1

echo "Waiting for VPC creation"

aws cloudformation wait stack-create-complete --stack-name EKS-Test

echo "Creates variable a for role arn, Security Group ID's and Subnets for EKS-Cluster"

ROLE="$(aws cloudformation describe-stacks --stack-name eks-service-role | \
jq -r '.Stacks[0] | .Outputs[0] | .OutputValue')"

SUBNETS="$(aws cloudformation describe-stacks --stack-name EKS-Test | \
jq -r '.Stacks[0] | .Outputs[2] | .OutputValue')"

SECURITY_GROUPS="$(aws cloudformation describe-stacks --stack-name EKS-Test | \
jq -r '.Stacks[0] | .Outputs[0] | .OutputValue')"

VPC_ID="$(aws cloudformation describe-stacks --stack-name EKS-Test | \
jq -r '.Stacks[0] | .Outputs[1] | .OutputValue')"

echo "Creating EKS-Cluster"

aws eks create-cluster \
      --name EKS-Cluster \
      --role-arn "$ROLE" \
      --resources-vpc-config subnetIds="$SUBNETS",securityGroupIds="$SECURITY_GROUPS"                   

echo "Creating EKS-Cluster..."

while ! aws eks describe-cluster --name EKS-Cluster  --query cluster.status --out text | grep -q ACTIVE; 
  do sleep "${SLEEP:=3}"
  echo -n .
done

echo "Cluster Created"

echo "Inserting cluster.endpoint and cluster.certificateAuthority.data into ~/.kube/config-EKS-Cluster"

CLUSTER_ENDPOINT="$(aws eks describe-cluster --name EKS-Cluster | \
jq -r '.[] | .endpoint')"

CA_DATA="$(aws eks describe-cluster --name EKS-Cluster | \
jq -r '.[] | .certificateAuthority | .data')"

echo "Creating .kube directory and creating kubeconfig file into ~/.kube/kubeconfig"

mkdir -p ~/.kube

cat >  ~/.kube/kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    server: "$CLUSTER_ENDPOINT"
    certificate-authority-data: "$CA_DATA"
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: heptio-authenticator-aws
      args:
        - "token"
        - "-i"
        - "EKS-Cluster"
EOF

export KUBECONFIG=$KUBECONFIG:~/.kube/kubeconfig

echo "Test for Kubectl"

kubectl get svc

echo "Create key pair for EKS access"

if ! aws ec2 describe-key-pairs --key-names EKS-Workers;
  then
    aws ec2 create-key-pair --key-name EKS-Workers --query 'KeyMaterial' --output text > "$HOME"/.ssh/id-eks.pem
    chmod 0400 "$HOME"/.ssh/EKS-Workers.pem;
  else
    echo "Key-pair is already created"
fi

echo "Creating EKS Workers"

aws cloudformation create-stack \
    --stack-name EKS-Workers  \
    --template-body file://eks-nodegroup.yaml \
          --capabilities CAPABILITY_IAM \
          --parameters \
        ParameterKey=NodeInstanceType,ParameterValue=t2.small \
        ParameterKey=NodeImageId,ParameterValue=ami-dea4d5a1 \
        ParameterKey=NodeGroupName,ParameterValue=EKS-Worker-Group \
        ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=1 \
        ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=3 \
        ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue="${SECURITY_GROUPS}" \
        ParameterKey=ClusterName,ParameterValue=EKS-Cluster \
        ParameterKey=Subnets,ParameterValue="${SUBNETS//,/\\,}" \
        ParameterKey=VpcId,ParameterValue="${VPC_ID}" \
        ParameterKey=KeyName,ParameterValue=EKS-Workers

echo "Creating EKS-Workers..."
aws cloudformation wait stack-create-complete --stack-name EKS-Workers

echo "Creating worker yaml file"

INSTANCE_ROLE="$(aws cloudformation describe-stacks --stack-name EKS-Workers | \
jq -r '.Stacks[0] | .Outputs[0] | .OutputValue')"

cat >  ~/.kube/aws-auth-cm.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: "$INSTANCE_ROLE"
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

echo "Applying aws auth to join workers"

kubectl apply -f ~/.kube/aws-auth-cm.yaml
sleep 8
echo "Checking for node joins"

while true;
do
  if ! kubectl get nodes | grep Not; then
    break
  fi
sleep 3
done
echo "Worker nodes have joined"