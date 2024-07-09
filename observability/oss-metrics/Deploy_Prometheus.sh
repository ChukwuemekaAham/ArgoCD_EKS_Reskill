#!/bin/bash

set -x

# Deploy Prometheus
# First we are going to install Prometheus. In this example, we are primarily going to use 
# the standard configuration, but we do override the storage class. We will use gp2 EBS volumes 
# for simplicity and demonstration purpose. When deploying in production, you would use io1 volumes
# with desired IOPS and increase the default storage size in the manifests to get better performance.
# Run the following command:

helm ls --all-namespaces

kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
helm repo update

# helm install prometheus prometheus-community/prometheus \
#     --namespace prometheus \
#     --set alertmanager.persistentVolume.storageClass="gp2" \
#     --set server.persistentVolume.storageClass="gp2"


helm install prometheus prometheus-community/prometheus -n prometheus -f prometheus_latest_values.yaml
# NAME: prometheus
# LAST DEPLOYED: Mon Jul  8 18:53:27 2024
# NAMESPACE: prometheus
# STATUS: deployed
# REVISION: 1
# TEST SUITE: None
# NOTES:
# The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
# prometheus-server.prometheus.svc.cluster.local


# Get the Prometheus server URL by running these commands in the same shell:    
#   export POD_NAME=$(kubectl get pods --namespace prometheus -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
#   kubectl --namespace prometheus port-forward $POD_NAME 9090


# The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
# prometheus-alertmanager.prometheus.svc.cluster.local


# Get the Alertmanager URL by running these commands in the same shell:
#   export POD_NAME=$(kubectl get pods --namespace prometheus -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
#   kubectl --namespace prometheus port-forward $POD_NAME 9093
# #################################################################################
# ######   WARNING: Pod Security Policy has been disabled by default since    #####
# ######            it deprecated after k8s 1.25+. use                        #####
# ######            (index .Values "prometheus-node-exporter" "rbac"          #####
# ###### .          "pspEnabled") with (index .Values                         #####
# ######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
# ######            in case you still need it.                                #####
# #################################################################################


# The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
# prometheus-prometheus-pushgateway.prometheus.svc.cluster.local


# Get the PushGateway URL by running these commands in the same shell:
#   export POD_NAME=$(kubectl get pods --namespace prometheus -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")  
#   kubectl --namespace prometheus port-forward $POD_NAME 9091

# For more information on running Prometheus, visit:
# https://prometheus.io/


kubectl get all -n prometheus

kubectl get pvc -n prometheus

kubectl port-forward -n prometheus deploy/prometheus-server 8080:9090

kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090


# $ kubectl --namespace=prometheus port-forward deploy/prometheus-server 9090
# Forwarding from 127.0.0.1:9090 -> 9090
# Forwarding from [::1]:9090 -> 9090
# Handling connection for 9090
# Handling connection for 9090
# Handling connection for 9090



