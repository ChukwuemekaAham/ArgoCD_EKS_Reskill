#!/bin/bash

set -x

# We will use helm to install Prometheus & Grafana monitoring tools

# add prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# add grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts


# helm upgrade prometheus-chart-name prometheus-community/prometheus -n prometheus_namespace -f my_prometheus_values_yaml --version current_helm_chart_version