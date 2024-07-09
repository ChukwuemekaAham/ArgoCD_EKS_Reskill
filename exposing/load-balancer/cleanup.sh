#!/bin/bash

set -e

kubectl delete svc -n ui ui-nlb --ignore-not-found

# uninstall-helm-chart aws-load-balancer-controller kube-system
helm list -n kube-system

# NAME                            NAMESPACE       REVISION  UPDATED                                  STATUS          CHART                              APP VERSION
# aws-load-balancer-controller    kube-system     1         2024-07-07 22:59:50.8140828 +0100 WAT    deployed        aws-load-balancer-controller-1.8.1 v2.8.1  

helm uninstall aws-load-balancer-controller -n kube-system