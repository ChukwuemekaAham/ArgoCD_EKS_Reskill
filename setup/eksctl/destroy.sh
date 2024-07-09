#!/bin/bash

set -x

eksctl delete cluster $EKS_CLUSTER_NAME --wait
