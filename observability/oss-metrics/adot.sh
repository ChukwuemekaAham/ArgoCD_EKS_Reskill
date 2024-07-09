#!/bin/bash

set -x

# https://docs.aws.amazon.com/eks/latest/userguide/opentelemetry.html

# https://aws-otel.github.io/docs/getting-started/adot-eks-add-on

# https://aws-otel.github.io/docs/getting-started/advanced-prometheus-remote-write-configurations

# Prerequisites
# Before getting started, you will need to set up the following components:

# An AMP workspace should be set up. Guides for this can be found here.
# A Kubernetes or EKS cluster. The EKS cluster can be on either EC2 or Fargate. 
# If you need to set up an EKS cluster, please use the following guide. You can 
# check the name of the active context/cluster using this command kubectl config 
# current-context.
# If you are setting up the ADOT Collector of AWS EKS, you will need to set up
# IAM roles for service accounts for the ingestion of metrics from Amazon 
# EKS clusters. Please follow the To set up IRSA for ingestion into AMP section. 
# This section will create a IAM role for the service account that we will use for 
# the ADOT Collector to scrape and export metrics.

# https://docs.aws.amazon.com/prometheus/latest/userguide/set-up-irsa.html#set-up-irsa-ingest

cluster_name=reskillCluster

# To use IAM roles for service accounts in the cluster, 

aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

# an OIDC identity provider need to be created

eksctl utils associate-iam-oidc-provider \
    --cluster reskillCluster \
    --approve

chmod +x createIRSA-AMPIngest.sh
chmod +x createIRSA-AMPQuery.sh

# Run the script:

./createIRSA-AMPIngest.sh
./createIRSA-AMPQuery.sh

# Install the OpenTelemetry Collector CRDs:
# Download the latest CRD manifest from the OpenTelemetry Collector repository: 
# Apply the CRD manifest to your Kubernetes cluster:

kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

kubectl apply -k ./observability/oss-metrics/adot


# $ kubectl get ValidatingWebhookConfiguration
# NAME                                                      WEBHOOKS   AGE
# aws-load-balancer-webhook                                 3          5h37m
# eks-aws-auth-configmap-validation-webhook                 1          28h
# opentelemetry-operator-validating-webhook-configuration   6          26m
# vpc-resource-validating-webhook                           2          28h

# $ kubectl get MutatingWebhookConfiguration
# NAME                                                    WEBHOOKS   AGE
# aws-load-balancer-webhook                               3          5h38m
# opentelemetry-operator-mutating-webhook-configuration   4          27m
# pod-identity-webhook                                    1          28h
# vpc-resource-mutating-webhook                           1          28h


# The provided OpenTelemetry collector configuration seems well-structured and configured for scraping Kubernetes metrics with Prometheus and exporting them to an AWS managed Prometheus instance using SigV4 authentication. 

