EKS Cluster Script
===
This script will automatically create a three node cluster in us-east.

The script will install heptio-authenticatior which is required to allow IAM authentication for your Kubernetes cluster. 
In the scritp it is preconfigured to install to MacOS.
If you need change which OS you can change which link is used to curl. Below are the links that are on the [AWS EKS getting started page](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

```
Linux: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/linux/amd64/kubectl
MacOS: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/darwin/amd64/kubectl
Windows: https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-06-05/bin/windows/amd64/kubectl.exe
```
If you need to change what size nodes, how many nodes auto scale at minimum or nodes auto-scale at maximum you can change the parameters below.

```
ParameterKey=NodeInstanceType,ParameterValue=t2.small \
ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=1 \
ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=3 \
```
Your cluster is complete when you see the "Worker nodes have joined" line.

To cleanup and delete you cluster you can run the `cleanup.sh` command after the "Worker nodes have joined"

This will delete the SSH key, service role, EKS Workers, EKS Cluster and EKS VPC.

Credit to Amazon's [EKS Getting Started page](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) and [Banzais EKS script](https://github.com/banzaicloud/eks-getting-started) which helped with the creation of this script.
