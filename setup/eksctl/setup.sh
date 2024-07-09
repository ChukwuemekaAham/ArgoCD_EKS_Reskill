#!/bin/bash

set -x

export EKS_CLUSTER_NAME=reskillCluster

curl -fsSL https://raw.githubusercontent.com/aws-samples/eks-workshop-v2/stable/cluster/eksctl/cluster.yaml | \
envsubst | eksctl create cluster -f -

