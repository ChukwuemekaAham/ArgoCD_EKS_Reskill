#!/bin/bash

set -x

# EBS_CSI_ADDON_ROLE=

# EBS_CSI_ADDON_ROLE=

# cluster_name=reskillCluster

#To use IAM roles for service accounts in the cluster, 

aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

#an OIDC identity provider need to be created

# eksctl utils associate-iam-oidc-provider \
#     --cluster reskillCluster \
#     --approve

# https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html

# https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html

aws eks describe-addon-versions --addon-name aws-ebs-csi-driver

eksctl create addon --name aws-ebs-csi-driver --cluster my-cluster --service-account-role-arn arn:aws:iam::111122223333:role/AmazonEKS_EBS_CSI_DriverRole --force


aws iam create-policy \
    --policy-name EbsCsiIAMPolicy \
    --policy-document file://ebs-csi_policy.json


# {
#     "Policy": {
#         "PolicyName": "EbsCsiIAMPolicy",
#         "PolicyId": "ANPA5AJKRIP2QWPNSXLQX",
#         "Arn": "arn:aws:iam::893979280373:policy/EbsCsiIAMPolicy",
#         "Path": "/",
#         "DefaultVersionId": "v1",
#         "AttachmentCount": 0,
#         "PermissionsBoundaryUsageCount": 0,
#         "IsAttachable": true,
#         "CreateDate": "2024-07-08T12:34:57+00:00",
#         "UpdateDate": "2024-07-08T12:34:57+00:00"
#     }
# }

eksctl create iamserviceaccount \
  --cluster reskillCluster \
  --region us-east-2 \
  --namespace kube-system \
  --name aws-ebs-csi-driver \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn "arn:aws:iam::893979280373:policy/EbsCsiIAMPolicy" \
  --approve \
  --override-existing-serviceaccounts

#   2024-07-08 14:25:39 [ℹ]  1 existing iamserviceaccount(s) (kube-system/aws-load-balancer-controller) will be excluded
# 2024-07-08 14:25:39 [ℹ]  1 iamserviceaccount (kube-system/aws-ebs-csi-driver) was included (based on the include/exclude rules) 
# 2024-07-08 14:25:39 [!]  metadata of serviceaccounts that exist in Kubernetes will be updated, as --override-existing-serviceaccounts was set
# 2024-07-08 14:25:39 [ℹ]  1 task: { 
#     2 sequential sub-tasks: {
#         create IAM role for serviceaccount "kube-system/aws-ebs-csi-driver",
#         create serviceaccount "kube-system/aws-ebs-csi-driver", 
#     } }2024-07-08 14:25:39 [ℹ]  building iamserviceaccount stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-ebs-csi-driver"
# 2024-07-08 14:25:39 [ℹ]  deploying stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-ebs-csi-driver"
# 2024-07-08 14:25:40 [ℹ]  waiting for CloudFormation stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-ebs-csi-driver"
# 2024-07-08 14:26:28 [ℹ]  waiting for CloudFormation stack "eksctl-reskillCluster-addon-iamserviceaccount-kube-system-aws-ebs-csi-driver"
# 2024-07-08 14:27:08 [ℹ]  created serviceaccount "kube-system/aws-ebs-csi-driver"



aws eks create-addon --cluster-name reskillCluster --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::893979280373:role/AmazonEKS_EBS_CSI_DriverRole

# {
#     "addon": {
#         "addonName": "aws-ebs-csi-driver",
#         "clusterName": "reskillCluster",
#         "status": "CREATING",
#         "addonVersion": "v1.32.0-eksbuild.1",
#         "health": {
#             "issues": []
#         },
#         "addonArn": "arn:aws:eks:us-east-2:893979280373:addon/reskillCluster/aws-ebs-csi-driver/38c84947-389f-7448-8a1e-c099f11c76f1",
#         "createdAt": "2024-07-08T14:35:27.204000+01:00",       
#         "modifiedAt": "2024-07-08T14:35:27.219000+01:00",      
#         "serviceAccountRoleArn": "arn:aws:iam::893979280373:role/AmazonEKS_EBS_CSI_DriverRole",
#         "tags": {}
#     }
# }

aws eks wait addon-active --cluster-name reskillCluster --addon-name aws-ebs-csi-driver

kubectl get daemonset ebs-csi-node -n kube-system

# NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
# ebs-csi-node   3         3         3       3            3           kubernetes.io/os=linux   3m14s

kubectl get storageclass

$ kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  25h


kubectl apply -k ./storage/ebs/

# namespace/catalog configured
# serviceaccount/catalog configured
# configmap/catalog configured
# secret/catalog-db configured
# service/catalog configured
# service/catalog-mysql configured
# service/catalog-mysql-ebs created
# deployment.apps/catalog configured
# statefulset.apps/catalog-mysql configured
# statefulset.apps/catalog-mysql-ebs created

