#!/bin/bash

set -x


curl --remote-name-all https://raw.githubusercontent.com/aws-samples/eks-workshop-v2/stable/cluster/terraform/{main.tf,variables.tf,providers.tf,vpc.tf,eks.tf}

export EKS_CLUSTER_NAME=reskillCluster

terraform init
terraform apply -var="cluster_name=$EKS_CLUSTER_NAME" -auto-approve

use-cluster $EKS_CLUSTER_NAME
