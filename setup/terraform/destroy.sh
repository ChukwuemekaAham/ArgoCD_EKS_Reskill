#!/bin/bash

set -x


terraform destroy -var="cluster_name=$EKS_CLUSTER_NAME" -auto-approve