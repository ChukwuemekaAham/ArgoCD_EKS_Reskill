#!/bin/bash

set -x


# cluster_name=reskillCluster

#To use IAM roles for service accounts in the cluster, 

aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

#an OIDC identity provider need to be created

eksctl utils associate-iam-oidc-provider \
    --cluster reskillCluster \
    --approve


#EXAMPLE    

# Creating an IAM policy for the service account that will allow CA pod to interact with 
# the autoscaling groups.

# aws iam create-policy   \
#   --policy-name k8s-policy \
#   --policy-document file://k8s-policy.json

# #IAM role for the service-account-name Service Account in the kube-system namespace.

# eksctl create iamserviceaccount \
#     --name service-account-name \
#     --namespace kube-system \
#     --cluster reskillCluster \
#     --attach-policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/k8s-policy" \
#     --approve \
#     --override-existing-serviceaccounts


# #To ensure service account with the ARN of the IAM role is annotated
# kubectl -n kube-system describe sa service-account-name

# Output


# Name:                service-account-name
# Namespace:           kube-system
# Labels:              <none>
# Annotations:         eks.amazonaws.com/role-arn: arn:aws:iam::263022081217:role/eksctl-reskillCluster-addon-iamserviceac-Role1-12LNPCGBD6IPZ
# Image pull secrets:  <none>
# Mountable secrets:   service-account-name-token-vfk8n
# Tokens:              service-account-name-token-vfk8n
# Events:              <none>

# https://docs.aws.amazon.com/eks/latest/userguide/lbc-manifest.html


# curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json


aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# {
#     "Policy": {
#         "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
#         "PolicyId": "ANPA5AJKRIP24MV5OFEBP",      
#         "Arn": "arn:aws:iam::893979280373:policy/AWSLoadBalancerControllerIAMPolicy",
#         "Path": "/",
#         "DefaultVersionId": "v1",
#         "AttachmentCount": 0,
#         "PermissionsBoundaryUsageCount": 0,       
#         "IsAttachable": true,
#         "CreateDate": "2024-07-08T10:38:21+00:00",        
#         "UpdateDate": "2024-07-08T10:38:21+00:00"
#     }
# }



eksctl create iamserviceaccount \
  --cluster reskillCluster \
  --region us-east-2 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn "arn:aws:iam::893979280373:policy/AWSLoadBalancerControllerIAMPolicy" \
  --approve \
  --override-existing-serviceaccounts

# $ eksctl create iamserviceaccount \
#   --cluster reskillCluster \
#   --region us-east-2 \
#   --namespace kube-system \
#   --name aws-load-balancer-controller \
#   --role-name AmazonEKSLoadBalancerControllerRole \   
#   --attach-policy-arn "arn:aws:iam::893979280373:policy/AWSLoadBalancerControllerIAMPolicy" \
#   --approve
# 2024-07-08 11:50:01 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)
# 2024-07-08 11:50:01 [!]  serviceaccounts that exist in Kubernetes will be excluded, use --override-existing-serviceaccounts to override
# 2024-07-08 11:50:01 [ℹ]  1 task: { 
#     2 sequential sub-tasks: {
#         create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
#         create serviceaccount "kube-system/aws-load-balancer-controller",
#     } }2024-07-08 11:50:01 [ℹ]  building iamserviceaccount stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
# 2024-07-08 11:50:02 [ℹ]  deploying stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
# 2024-07-08 11:50:02 [ℹ]  waiting for CloudFormation stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
# 2024-07-08 11:50:34 [ℹ]  waiting for CloudFormation stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
# 2024-07-08 11:50:35 [ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"

# $ eksctl create iamserviceaccount \
#   --cluster reskillCluster \
#   --region us-east-2 \
#   --namespace kube-system \
#   --name aws-load-balancer-controller \
#   --role-name AmazonEKSLoadBalancerControllerRole \   
#   --attach-policy-arn "arn:aws:iam::893979280373:policy/AWSLoadBalancerControllerIAMPolicy" \
#   --approve \
#   --override-existing-serviceaccounts
# 2024-07-08 11:51:27 [ℹ]  1 existing iamserviceaccount(s) (kube-system/aws-load-balancer-controller) will be excluded
# 2024-07-08 11:51:27 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was excluded (based on the include/exclude rules)
# 2024-07-08 11:51:27 [!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set
# 2024-07-08 11:51:27 [ℹ]  no tasks

wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml 

kubectl apply -f crds.yaml

helm search repo eks/aws-load-balancer-controller --versions

helm upgrade --install aws-load-balancer-controller eks-charts/aws-load-balancer-controller \
  --version "1.8.1" \
  --namespace "kube-system" \
  --set "clusterName=reskillCluster" \
  --set "serviceAccount.create=false" \
  --set "serviceAccount.name=aws-load-balancer-controller" \
  --set "region=us-east-2"

kubectl get deployment -n kube-system aws-load-balancer-controller

$ kubectl get deployment -n kube-system aws-load-balancer-controller
# NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
# aws-load-balancer-controller   2/2     2            2           25s

$ kubectl apply -k ./exposing/load-balancer/nlb
# kubectl get service -n ui
# NAME     TYPE           CLUSTER-IP       EXTERNAL-IP                                                            PORT(S)        AGE
# kubectl get service -n ui
# NAME     TYPE           CLUSTER-IP       EXTERNAL-IP                                                            PORT(S)        AGE
# ui       ClusterIP      10.100.171.121   <none>                                                                 80/TCP         14h
# ui-nlb   LoadBalancer   10.100.102.96    k8s-ui-uinlb-34c0fa10fc-06598ddcf32d499c.elb.us-east-2.amazonaws.com   80:32452/TCP   15s