# EKS open source observability

$ prepare-environment observability/oss-metrics
This will make the following changes to your lab environment:

Install the EKS managed addon for AWS Distro for OpenTelemetry
Create an IAM role for the ADOT collector to access Amazon Managed Prometheus
You can view the Terraform that applies these changes here.

In this lab, we'll collect the metrics from the application using AWS Distro for OpenTelemetry, store the metrics in Amazon Managed Service for Prometheus and visualize using Amazon Managed Grafana.

AWS Distro for OpenTelemetry is a secure, production-ready, AWS-supported distribution of the OpenTelemetry project . Part of the Cloud Native Computing Foundation, OpenTelemetry provides open source APIs, libraries, and agents to collect distributed traces and metrics for application monitoring. With AWS Distro for OpenTelemetry, you can instrument your applications just once to send correlated metrics and traces to multiple AWS and Partner monitoring solutions. Use auto-instrumentation agents to collect traces without changing your code. AWS Distro for OpenTelemetry also collects metadata from your AWS resources and managed services, so you can correlate application performance data with underlying infrastructure data, reducing the mean time to problem resolution. Use AWS Distro for OpenTelemetry to instrument your applications running on Amazon Elastic Compute Cloud (EC2), Amazon Elastic Container Service (ECS), and Amazon Elastic Kubernetes Service (EKS) on EC2, AWS Fargate, and AWS Lambda, as well as on-premises.

The ADOT-AMP pipeline enables us to use the ADOT Collector to scrape a Prometheus-instrumented application, and send the scraped metrics to AWS Managed Service for Prometheus (AMP).

Amazon Managed Service for Prometheus is a monitoring service for metrics compatible with the open source Prometheus project, making it easier for you to securely monitor container environments. Amazon Managed Service for Prometheus is a solution for monitoring containers based on the popular Cloud Native Computing Foundation (CNCF) Prometheus project. Amazon Managed Service for Prometheus reduces the heavy lifting required to get started with monitoring applications across Amazon Elastic Kubernetes Service and Amazon Elastic Container Service, as well as self-managed Kubernetes clusters.



Explanation of Sections:

apiVersion: Specifies the OpenTelemetry collector API version.
kind: Declares the kind of resource as OpenTelemetryCollector.
metadata: Defines metadata for the collector deployment (name: adot, namespace: other).
spec: Configures the collector:
image: Specifies the Docker image for the collector (AWS OpenTelemetry Collector).
mode: Sets the deployment mode (deployment in this case).
serviceAccount: Defines the service account used by the collector pod.
config: Defines the collector configuration in YAML format.
receivers: Configures receivers for collecting telemetry data.
prometheus: Scrapes metrics from Prometheus endpoints.
config: Defines configuration for the Prometheus receiver.
global: Sets global scraping settings (interval, timeout).
external_labels: Adds static labels to all scraped metrics.
scrape_configs: Defines specific scraping configurations for different targets.
Each configuration defines job name, scraping interval/timeout, scheme (HTTPS), TLS configuration, and Kubernetes service discovery configuration for scraping metrics from kubelets and pods.
exporters: Configures exporters for sending collected data.
prometheusremotewrite: Exports metrics to a remote Prometheus endpoint.
endpoint: URL of the remote Prometheus instance.
auth: Configures authentication for the remote write endpoint.
authenticator: Specifies SigV4 authentication.
logging: Sets the logging level for the collector (info in this case).
extensions: Registers extensions used by the collector.
sigv4auth: Configures SigV4 authentication for the remote write exporter.
region: AWS region where the remote Prometheus instance resides.
service: Service name used for SigV4 authentication (APS in this case).
health_check: Defines health checks for the collector.
pprof: Enables pprof endpoint for profiling.
zpages: Enables zpages endpoint for diagnostics.
service: Configures the collector service.
extensions: Lists enabled extensions (including health check, SigV4 auth, etc.).
pipelines: Defines data processing pipelines.
metrics: Pipeline for handling metrics.
receivers: List of receivers feeding data to the pipeline (Prometheus in this case).
exporters: List of exporters receiving data from the pipeline (logging and prometheusremotewrite).
Potential Improvements:

Insecure Skip Verify: Consider removing insecure_skip_verify: true if you have a valid TLS certificate for the Kubernetes API server. This improves security by ensuring proper certificate verification.
Targeted Scraping: You can further enhance configuration by defining specific scrape targets within the scrape_configs section using Kubernetes labels as selectors. This allows for more granular control over scraped metrics.
Additional Extensions: OpenTelemetry Collector offers various extensions for processing and exporting data. Explore documentation for extensions if you need additional features like data transformation or correlation.
Testing and Validation:

After deploying the collector with this configuration, verify that it's scraping metrics successfully. Use tools like kubectl logs to check collector logs for errors. You can also utilize Prometheus to query metrics and confirm they are being received from the collector.

By keeping these points in mind and potentially incorporating the suggested improvements, you can leverage this OpenTelemetry collector configuration to effectively collect and export Kubernetes metrics to your AWS managed Prometheus instance.



helm repo update

# Deploy Prometheus
# First we are going to install Prometheus. In this example, we are primarily going to use 
# the standard configuration, but we do override the storage class. We will use gp2 EBS volumes 
# for simplicity and demonstration purpose. When deploying in production, you would use io1 volumes
# with desired IOPS and increase the default storage size in the manifests to get better performance.


# Run the following command:


kubectl create namespace prometheus

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install prometheus prometheus-community/prometheus --namespace prometheus --set alertmanager.persistentVolume.storageClass="gp2" --set server.persistentVolume.storageClass="gp2"


$ helm install prometheus prometheus-community/prometheus --namespace prometheus --set alertmanager.persistentVolume.storageClass="gp2" --set server.persistentVolume.storageClass="gp2"
NAME: prometheus
LAST DEPLOYED: Mon Jul  8 09:16:10 2024
NAMESPACE: prometheus
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
prometheus-server.prometheus.svc.cluster.local


Get the Prometheus server URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace prometheus -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")   
  kubectl --namespace prometheus port-forward $POD_NAME 9090


The Prometheus alertmanager can be accessed via port 9093 on the following DNS name from within your cluster:
prometheus-alertmanager.prometheus.svc.cluster.local        


Get the Alertmanager URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace prometheus -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}") 
  kubectl --namespace prometheus port-forward $POD_NAME 9093
#################################################################################
######   WARNING: Pod Security Policy has been disabled by default since    #####
######            it deprecated after k8s 1.25+. use                        #####
######            (index .Values "prometheus-node-exporter" "rbac"          #####
###### .          "pspEnabled") with (index .Values         
                #####
######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
######            in case you still need it.                
                #####
#################################################################################


The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
prometheus-prometheus-pushgateway.prometheus.svc.cluster.local


Get the PushGateway URL by running these commands in the same shell:
  export POD_NAME=$(kubectl get pods --namespace prometheus -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace prometheus port-forward $POD_NAME 9091

For more information on running Prometheus, visit:
https://prometheus.io/

/Cloud/00-reskill/ArgoCD_Reskill
$

kubectl get all -n prometheus


$ kubectl get pvc -n prometheus
NAME                                STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
prometheus-server                   Pending                                      gp2            11m
storage-prometheus-alertmanager-0   Pending                                      gp2            11m   



$ kubectl get events -n prometheus
LAST SEEN   TYPE      REASON                   OBJECT                                                    MESSAGE
3m3s        Warning   FailedScheduling         pod/prometheus-alertmanager-0                             running PreBind plugin "VolumeBinding": binding volumes: timed out waiting for the condition
13m         Normal    SuccessfulCreate         statefulset/prometheus-alertmanager                    
   create Claim storage-prometheus-alertmanager-0 Pod prometheus-alertmanager-0 in StatefulSet prometheus-alertmanager success
13m         Normal    SuccessfulCreate         statefulset/prometheus-alertmanager                    
   create Pod prometheus-alertmanager-0 in StatefulSet prometheus-alertmanager successful
13m         Normal    Scheduled                pod/prometheus-kube-state-metrics-58986455cd-lw877     
   Successfully assigned prometheus/prometheus-kube-state-metrics-58986455cd-lw877 to ip-192-168-32-131.us-east-2.compute.internal
13m         Normal    Pulled                   pod/prometheus-kube-state-metrics-58986455cd-lw877        Container image "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.12.0" already present on machine
13m         Normal    Created                  pod/prometheus-kube-state-metrics-58986455cd-lw877        Created container kube-state-metrics
13m         Normal    Started                  pod/prometheus-kube-state-metrics-58986455cd-lw877        Started container kube-state-metrics
13m         Normal    SuccessfulCreate         replicaset/prometheus-kube-state-metrics-58986455cd       Created pod: prometheus-kube-state-metrics-58986455cd-lw877
13m         Normal    ScalingReplicaSet        deployment/prometheus-kube-state-metrics               
   Scaled up replica set prometheus-kube-state-metrics-58986455cd to 1
13m         Normal    Scheduled                pod/prometheus-prometheus-node-exporter-4zpxf          
   Successfully assigned prometheus/prometheus-prometheus-node-exporter-4zpxf to ip-192-168-32-131.us-east-2.compute.internal
13m         Normal    Pulled                   pod/prometheus-prometheus-node-exporter-4zpxf          
   Container image "quay.io/prometheus/node-exporter:v1.8.1" already present on machine
13m         Normal    Created                  pod/prometheus-prometheus-node-exporter-4zpxf          
   Created container node-exporter
13m         Normal    Started                  pod/prometheus-prometheus-node-exporter-4zpxf          
   Started container node-exporter
13m         Normal    Scheduled                pod/prometheus-prometheus-node-exporter-5wzlx          
   Successfully assigned prometheus/prometheus-prometheus-node-exporter-5wzlx to ip-192-168-8-139.us-east-2.compute.internal
13m         Normal    Pulled                   pod/prometheus-prometheus-node-exporter-5wzlx          
   Container image "quay.io/prometheus/node-exporter:v1.8.1" already present on machine
13m         Normal    Created                  pod/prometheus-prometheus-node-exporter-5wzlx          
   Created container node-exporter
13m         Normal    Started                  pod/prometheus-prometheus-node-exporter-5wzlx          
   Started container node-exporter
13m         Normal    Scheduled                pod/prometheus-prometheus-node-exporter-pjkcd          
   Successfully assigned prometheus/prometheus-prometheus-node-exporter-pjkcd to ip-192-168-79-172.us-east-2.compute.internal
13m         Normal    Pulled                   pod/prometheus-prometheus-node-exporter-pjkcd          
   Container image "quay.io/prometheus/node-exporter:v1.8.1" already present on machine
13m         Normal    Created                  pod/prometheus-prometheus-node-exporter-pjkcd          
   Created container node-exporter
13m         Normal    Started                  pod/prometheus-prometheus-node-exporter-pjkcd          
   Started container node-exporter
13m         Normal    SuccessfulCreate         daemonset/prometheus-prometheus-node-exporter          
   Created pod: prometheus-prometheus-node-exporter-5wzlx
13m         Normal    SuccessfulCreate         daemonset/prometheus-prometheus-node-exporter          
   Created pod: prometheus-prometheus-node-exporter-pjkcd
13m         Normal    SuccessfulCreate         daemonset/prometheus-prometheus-node-exporter          
   Created pod: prometheus-prometheus-node-exporter-4zpxf
13m         Warning   FailedToUpdateEndpoint   endpoints/prometheus-prometheus-node-exporter          
   Failed to update endpoint prometheus/prometheus-prometheus-node-exporter: Operation cannot be fulfilled on endpoints "prometheus-prometheus-node-exporter": the object has been modified; please apply your changes to the latest version and try again
13m         Normal    Scheduled                pod/prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt    Successfully assigned prometheus/prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt to ip-192-168-8-139.us-east-2.compute.internal
13m         Normal    Pulled                   pod/prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt    Container image "quay.io/prometheus/pushgateway:v1.8.0" already present on machine
13m         Normal    Created                  pod/prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt    Created container pushgateway
13m         Normal    Started                  pod/prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt    Started container pushgateway
13m         Normal    SuccessfulCreate         replicaset/prometheus-prometheus-pushgateway-7b44fdf7dc   Created pod: prometheus-prometheus-pushgateway-7b44fdf7dc-5dclt
13m         Normal    ScalingReplicaSet        deployment/prometheus-prometheus-pushgateway           
   Scaled up replica set prometheus-prometheus-pushgateway-7b44fdf7dc to 1
3m4s        Warning   FailedScheduling         pod/prometheus-server-7dcfdcb8b4-h55mw                 
   running PreBind plugin "VolumeBinding": binding volumes: timed out waiting for the condition       
13m         Normal    SuccessfulCreate         replicaset/prometheus-server-7dcfdcb8b4                
   Created pod: prometheus-server-7dcfdcb8b4-h55mw
13m         Normal    WaitForFirstConsumer     persistentvolumeclaim/prometheus-server                
   waiting for first consumer to be created before binding
13m         Normal    ScalingReplicaSet        deployment/prometheus-server                           
   Scaled up replica set prometheus-server-7dcfdcb8b4 to 1
3m17s       Normal    ExternalProvisioning     persistentvolumeclaim/prometheus-server                
   waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" or manually created by system administrator
13m         Normal    WaitForFirstConsumer     persistentvolumeclaim/storage-prometheus-alertmanager-0   waiting for first consumer to be created before binding
3m2s        Normal    ExternalProvisioning     persistentvolumeclaim/storage-prometheus-alertmanager-0   waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" or manually created by system administrator


The Kubernetes built-in kubernetes.io/aws-ebs provisioner that you're using in your custom storage class definition relies on the EBS CSI driver to provision and manage the underlying Amazon EBS volumes.

# Check if the EBS CSI driver is installed
kubectl get pods -n kube-system | grep ebs-csi

# Check the status of the EBS CSI driver


$ kubectl describe daemonset ebs-csi-driver -n kube-system
Error from server (NotFound): daemonsets.apps "ebs-csi-driver" not found


$ oidc_id=$(aws eks describe-cluster --name reskillCluster --query "cluster.identity.oi
dc.issuer" --output text | cut -d '/' -f 5)


$ echo $oidc_id
A292218E6C0B42334AE2D32969FCD0FB


$ aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4


$ cluster_name=reskillCluster


$ eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
2024-07-08 09:55:05 [ℹ]  will create IAM Open ID Connect provider for cluster "reskillCluster" in "us-east-2"
2024-07-08 09:55:12 [✔]  created IAM Open ID Connect provider for cluster "reskillCluster" in "us-east-2"






