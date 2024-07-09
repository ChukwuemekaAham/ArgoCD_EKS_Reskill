# Sample application

The sample application models a simple web store application, where customers can browse a catalog, add items to their cart and complete an order through the checkout process.

The application has several components and dependencies:

## Component description

UI	- Provides the front end user interface and aggregates API calls to the various other services.
Catalog	- API for product listings and details
Cart - API for customer shopping carts
Checkout - API to orchestrate the checkout process
Orders - API to receive and process customer orders
Static assets - Serves static assets like images related to the product catalog

<table><thead><tr><th>Component</th><th>Description</th></tr></thead><tbody><tr><td>UI</td><td>Provides the front end user interface and aggregates API calls to the various other services.</td></tr><tr><td>Catalog</td><td>API for product listings and details</td></tr><tr><td>Cart</td><td>API for customer shopping carts</td></tr><tr><td>Checkout</td><td>API to orchestrate the checkout process</td></tr><tr><td>Orders</td><td>API to receive and process customer orders</td></tr><tr><td>Static assets</td><td>Serves static assets like images related to the product catalog</td></tr></tbody></table>

Initially we'll deploy the application in a manner that is self-contained in the Amazon EKS cluster, without using any AWS services like load balancers or a managed database. 

Over the course of the labs we'll leverage different features of EKS to take advantage of broader AWS services and features for our retail store.

You can find the full source code for the sample application on ![GitHub](https://github.com/aws-containers/retail-store-sample-app).

<hr />

# Packaging the components

Before a workload can be deployed to a Kubernetes distribution like EKS it first must be packaged as a container image and published to a container registry. Basic container topics like this are not covered as part of this workshop, and the sample application has container images already available in Amazon Elastic Container Registry for the labs we'll complete today.

The table below provides links to the ECR Public repository for each component, as well as the Dockerfile that was used to build each component.


<table><thead><tr><th>Component</th><th>ECR Public repository</th><th>Dockerfile</th></tr></thead><tbody><tr><td>UI</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-ui" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/images/java17/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr><tr><td>Catalog</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-catalog" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/images/go/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr><tr><td>Shopping cart</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-cart" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/images/java17/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr><tr><td>Checkout</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-checkout" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/images/nodejs/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr><tr><td>Orders</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-orders" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/images/java17/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr><tr><td>Assets</td><td><a href="https://gallery.ecr.aws/aws-containers/retail-store-sample-assets" target="_blank" rel="noopener noreferrer">Repository</a></td><td><a href="https://github.com/aws-containers/retail-store-sample-app/blob/main/src/assets/Dockerfile" target="_blank" rel="noopener noreferrer">Dockerfile</a></td></tr></tbody></table>


# Microservices on Kubernetes

Now that we're familiar with the overall architecture of the sample application, how will we initially deploy this in to EKS? Let's explore some of the Kubernetes building blocks by looking at the catalog component:

Catalog microservice in Kubernetes

There are a number of things to consider in this diagram:

The application that provides the catalog API runs as a Pod, which is the smallest deployable unit in Kubernetes. Application Pods will run the container images we outlined in the previous section.
The Pods that run for the catalog component are created by a Deployment which may manage one or more "replicas" of the catalog Pod, allowing it to scale horizontally.
A Service is an abstract way to expose an application running as a set of Pods, and this allows our catalog API to be called by other components inside the Kubernetes cluster. Each Service is given its own DNS entry.
We're starting this workshop with a MySQL database that runs inside our Kubernetes cluster as a StatefulSet, which is designed to manage stateful workloads.
All of these Kubernetes constructs are grouped in their own dedicated catalog Namespace. Each of the application components has its own Namespace.
Each of the components in the microservices architecture is conceptually similar to the catalog, using Deployments to manage application workload Pods and Services to route traffic to those Pods. If we expand out our view of the architecture we can consider how traffic is routed throughout the broader system:

Microservices in Kubernetes

The ui component receives HTTP requests from, for example, a users browser. It then makes HTTP requests to other API components in the architecture to fulfill that request and returns a response to the user. Each of the downstream components may have their own data stores or other infrastructure. The Namespaces are a logical grouping of the resources for each microservice and also act as a soft isolation boundary, which can be used to effectively implement controls using Kubernetes RBAC and Network Policies.



# Deploying our first component

The sample application is composed of a set of Kubernetes manifests organized in a way that can be easily applied with Kustomize. Kustomize is an open-source tool also provided as a native feature of the kubectl CLI. This workshop uses Kustomize to apply changes to Kubernetes manifests, making it easier to understand changes to manifest files without needing to manually edit YAML. As we work through the various modules of this workshop, we'll incrementally apply overlays and patches with Kustomize.

**Before we do anything lets inspect the current Namespaces in our EKS cluster:**

HP@DESKTOP-9MLLT14 MINGW64 ~/Downloads/Cloud/00-reskill/ArgoCD_Reskill
$ kubectl get nodes
NAME                                           STATUS   ROLES    AGE   VERSION
ip-192-168-32-131.us-east-2.compute.internal   Ready    <none>   9h    v1.23.17-eks-ae9a62a       
ip-192-168-79-172.us-east-2.compute.internal   Ready    <none>   9h    v1.23.17-eks-ae9a62a       
ip-192-168-8-139.us-east-2.compute.internal    Ready    <none>   9h    v1.23.17-eks-ae9a62a 

HP@DESKTOP-9MLLT14 MINGW64 ~/Downloads/Cloud/00-reskill/ArgoCD_Reskill

$ kubectl get namespaces
NAME              STATUS   AGE
argocd            Active   7h38m     
assets            Active   64m       
carts             Active   64m
catalog           Active   64m       
checkout          Active   64m       
default           Active   9h        
kube-node-lease   Active   9h        
kube-public       Active   9h        
kube-system       Active   9h        
orders            Active   64m       
other             Active   64m
rabbitmq          Active   64m       
ui                Active   64m

$ kubectl get deployment -l app.kubernetes.io/created-by=eks-workshop -A
NAMESPACE   NAME             READY   UP-TO-DATE   AVAILABLE   AGE
assets      assets           1/1     1            1           65m
carts       carts            1/1     1            1           65m
carts       carts-dynamodb   1/1     1            1           65m
catalog     catalog          1/1     1            1           64m
checkout    checkout         1/1     1            1           64m
checkout    checkout-redis   1/1     1            1           64m
orders      orders           1/1     1            1           64m
orders      orders-mysql     1/1     1            1           64m
ui          ui               3/3     3            3           65m


# Helm

$
prepare-environment introduction/helm
Although we will primarily be interacting with kustomize in this workshop, there will be situations where Helm will be used to install certain packages in the EKS cluster. In this lab we give a brief introduction to Helm, and we'll demonstrate how to use it to install a pre-packaged application.


Helm is a package manager for Kubernetes that helps you define, install, and upgrade Kubernetes applications. It uses a packaging format called charts, which contain all the necessary Kubernetes resource definitions to run an application. Helm simplifies the deployment and management of applications on Kubernetes clusters.

Helm CLI
The helm CLI tool is typically used in conjunction with a Kubernetes cluster to manage the deployment and lifecycle of applications. It provides a consistent and repeatable way to package, install, and manage applications on Kubernetes, making it easier to automate and sta


$ helm version

Helm repositories
A Helm repository is a centralized location where Helm charts are stored and managed, and allow users to easily discover, share, and install charts. They facilitate easy access to a wide range of pre-packaged applications and services for deployment on Kubernetes clusters.

The Bitnami Helm repository is a collection of Helm charts for deploying popular applications and tools on Kubernetes. Let's add the bitnami repository to our Helm CLI:


$ helm repo add bitnami https://charts.bitnami.com/bitnami

$ helm repo update
Now we can search the repository for charts, for example the postgresql chart:

~
$
helm search repo postgresql
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
bitnami/postgresql      X.X.X           X.X.X           PostgreSQL (Postgres) is an open source object-...
[...]
Installing a Helm chart
Let's install an NGINX server in our EKS cluster using the Helm chart we found above. When you install a chart using the Helm package manager, it creates a new release for that chart. Each release is tracked by Helm and can be upgraded, rolled back, or uninstalled independently from other releases.

~
$
echo $NGINX_CHART_VERSION
~
$
helm install nginx bitnami/nginx \
  --version $NGINX_CHART_VERSION \
  --namespace nginx --create-namespace --wait

We can break this command down as follows:

Use the install sub-command to instruct Helm to install a chart
Name the release nginx
Use the chart bitnami/nginx with the version $NGINX_CHART_VERSION
Install the chart in the nginx namespace and create that namespace first
Wait for pods in the release to get to a ready state
Once the chart has installed we can list the releases in our EKS cluster:


$
helm list -A
NAME 	 NAMESPACE  REVISION  UPDATED                                  STATUS    CHART         APP VERSION
nginx	 nginx      1         2024-06-11 03:58:39.862100855 +0000 UTC  deployed  nginx-X.X.X   X.X.X
We can also see NGINX running in the namespace we specified:


$
kubectl get pod -n nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-55fbd7f494-zplwx   1/1     Running   0          119s
Configuring chart options
In the example above we installed the NGINX chart in its default configuration. Sometimes you'll need to provide configuration values to charts during installation to modify the way the component behaves.

There are two common ways to provide values to charts during installation:

Create YAML files and pass them to Helm using the -f or --values flag
Pass values using the --set flag followed by key=value pairs
Let's combine these methods to update our NGINX release. We'll use this values.yaml file:

~/environment/eks-workshop/modules/introduction/helm/values.yaml
podLabels:
  team: team1
  costCenter: org1

resources:
  requests:
    cpu: 250m
    memory: 256Mi


This adds several custom Kubernetes labels to the NGINX pods, as well as setting some resource requests.

We'll also add additional replicas using the --set flag:

$
helm upgrade --install nginx bitnami/nginx \
  --version $NGINX_CHART_VERSION \
  --namespace nginx --create-namespace --wait \
  --set replicaCount=3 \
  --values ~/environment/eks-workshop/modules/introduction/helm/values.yaml
List the releases:


$
helm list -A
NAME 	 NAMESPACE  REVISION  UPDATED                                  STATUS    CHART         APP VERSION
nginx	 nginx      2         2024-06-11 04:13:53.862100855 +0000 UTC  deployed  nginx-X.X.X   X.X.X
You'll notice that the revision column has updated to 2 as Helm has applied our updated configuration as a distinct revision. This would allow us to rollback to our previous configuration if necessary.

You can view the revision history of a given release like this:


$
helm history nginx -n nginx
REVISION  UPDATED                   STATUS      CHART        APP VERSION  DESCRIPTION
1         Tue Jun 11 03:58:39 2024  superseded  nginx-X.X.X  X.X.X       Install complete
2         Tue Jun 11 04:13:53 2024  deployed    nginx-X.X.X  X.X.X       Upgrade complete
To check that our changes have taken effect list the pods in the nginx namespace:


$
kubectl get pods -n nginx
NAME                     READY   STATUS    RESTARTS   AGE
nginx-55fbd7f494-4hz9b   1/1     Running   0          30s
nginx-55fbd7f494-gkr2j   1/1     Running   0          30s
nginx-55fbd7f494-zplwx   1/1     Running   0          5m
You can see we now have 3 replicas of the NGINX pod running.

Removing releases
We can similarly uninstall a release using the CLI:


$
helm uninstall nginx --namespace nginx --wait
This will delete all the resources created by the chart for that release from our EKS cluster.
