
# Exposing applications

create service account role see:

`irsa.sh` 

Right now our web store application is not exposed to the outside world, so there's no way for users to access it. Although there are many microservices in our web store workload, only the ui application needs to be available to end users. This is because the ui application will perform all communication to the other backend services using internal Kubernetes networking.

In this chapter of the workshop we'll take a look at the various mechanisms available when using EKS to expose an application to end users.

# AWS Load Balancer Controller
AWS Load Balancer Controller is a controller to help manage Elastic Load Balancers for a Kubernetes cluster.

The controller can provision the following resources:

An AWS Application Load Balancer when you create a Kubernetes Ingress.
An AWS Network Load Balancer when you create a Kubernetes Service of type LoadBalancer.
Application Load Balancers work at L7 of the OSI model, allowing you to expose Kubernetes service using ingress rules, and supports external-facing traffic. Network load balancers work at L4 of the OSI model, allowing you to leverage Kubernetes Services to expose a set of pods as an application network service.

The controller enables you to simplify operations and save costs by sharing an Application Load Balancer across multiple applications in your Kubernetes cluster.

The AWS Load Balancer Controller has already been installed in our cluster, so we can get started creating resources.

INFO
The AWS Load Balancer Controller was formerly named the AWS ALB Ingress Controller.

# Load Balancers

Kubernetes uses services to expose pods outside of a cluster. One of the most popular ways to use services in AWS is with the LoadBalancer type. With a simple YAML file declaring your service name, port, and label selector, the cloud controller will provision a load balancer for you automatically.

apiVersion: v1
kind: Service
metadata:
  name: search-svc # the name of our service
spec:
  type: loadBalancer
  selector:
    app: SearchApp # pods are deployed with the label app=SearchApp
  ports:
    - port: 80

This is great because of how simple it is to put a load balancer in front of your application. The service spec has been extended over the years with annotations and additional configuration. A second option is to use an ingress rule and an ingress controller to route external traffic into Kubernetes pods.

We can confirm our microservices are only accessible internally by taking a look at the current Service resources in the cluster:

$ kubectl get svc -l app.kubernetes.io/created-by=eks-workshop -A
NAMESPACE   NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                             
    AGE
assets      assets           ClusterIP   10.100.51.211    <none>        80/TCP                              
    75m
carts       carts            ClusterIP   10.100.127.250   <none>        80/TCP                              
    75m
carts       carts-dynamodb   ClusterIP   10.100.167.183   <none>        8000/TCP                            
    75m
catalog     catalog          ClusterIP   10.100.207.128   <none>        80/TCP                              
    75m
    75m
checkout    checkout         ClusterIP   10.100.161.30    <none>        80/TCP                                  75m
checkout    checkout-redis   ClusterIP   10.100.19.216    <none>        6379/TCP                                75m
orders      orders           ClusterIP   10.100.241.112   <none>        80/TCP                                  75m
orders      orders-mysql     ClusterIP   10.100.91.17     <none>        3306/TCP                                75m
rabbitmq    rabbitmq         ClusterIP   10.100.80.85     <none>        5672/TCP,4369/TCP,25672/TCP,15672/TCP   75m
ui          ui               ClusterIP   10.100.171.121   <none>        80/TCP                                  75m

HP@DESKTOP-9MLLT14 MINGW64 ~/Downloads/Cloud/00-reskill/ArgoCD_Reskill
All of our application components are currently using ClusterIP services, which only allows access to other workloads in the same Kubernetes cluster. In order for users to access our application we need to expose the ui application, and in this example we'll do so using a Kubernetes service of type LoadBalancer.

Lets take a closer look at the current specification of the service for the ui component:

$ kubectl -n ui describe service ui
Name:              ui
Namespace:         ui
Labels:            app.kubernetes.io/component=service
                   app.kubernetes.io/created-by=eks-workshop
                   app.kubernetes.io/instance=ui 
                   app.kubernetes.io/managed-by=Helm
                   app.kubernetes.io/name=ui     
                   argocd.argoproj.io/instance=ui
                   helm.sh/chart=ui-0.0.1        
Annotations:       <none>
Selector:          app.kubernetes.io/component=service,app.kubernetes.io/instance=ui,app.kubernetes.io/name=ui
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.100.171.121
IPs:               10.100.171.121
Port:              http  80/TCP
TargetPort:        http/TCP
Endpoints:         192.168.30.232:8080,192.168.51.42:8080,192.168.74.234:8080
Session Affinity:  None
Events:            <none>

As we saw earlier this is currently using a type ClusterIP and our task in this module is to change this so that the retail store user interface is accessible over the public Internet.


# Port forwarding

$ kubectl port-forward ui-fddcf8d7b-5tlm9 9090:8080 -n ui
Forwarding from 127.0.0.1:9090 -> 8080
Forwarding from [::1]:9090 -> 8080
Handling connection for 9090
Handling connection for 9090
Handling connection for 9090
Handling connection for 9090
Handling connection for 9090
Handling connection for 9090

# Creating the load balancer
Let's create an additional Service that provisions a load balancer with the following kustomization:

./exposing/load-balancer/nlb/nlb.yaml
apiVersion: v1
kind: Service
metadata:
  name: ui-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
  namespace: ui
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
      name: http
  selector:
    app.kubernetes.io/name: ui
    app.kubernetes.io/instance: ui
    app.kubernetes.io/component: service


This Service will create a Network Load Balancer that listens on port 80 and forwards connections to the ui Pods on port 8080. An NLB is a layer 4 load balancer that on our case operates at the TCP layer.

$ kubectl get deployment -n kube-system aws-load-balancer-controller
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           25s


$ kubectl apply -k ./argocd/exposing/load-balancer/nlb
kubectl get service -n ui
NAME     TYPE           CLUSTER-IP       EXTERNAL-IP                                                            PORT(S)        AGE
ui       ClusterIP      10.100.171.121   <none>                                                                 80/TCP         14h
ui-nlb   LoadBalancer   10.100.102.96    k8s-ui-uinlb-34c0fa10fc-06598ddcf32d499c.elb.us-east-2.amazonaws.com   80:32452/TCP   15s


The output above shows that we have 3 targets registered to the load balancer using the EC2 instance IDs (i-) each on the same port. The reason for this is that by default the AWS Load Balancer Controller operates in "instance mode", which targets traffic to the worker nodes in the EKS cluster and allows kube-proxy to forward traffic to individual Pods.

You can also inspect the NLB in the console by clicking this link:

https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#TargetGroup:targetGroupArn=arn:aws:elasticloadbalancing:us-east-2:893979280373:targetgroup/k8s-ui-uinlb-22b0fb1653/c53b102c0e8200d6


IP mode
As mentioned previously, the NLB we have created is operating in "instance mode". Instance target mode supports pods running on AWS EC2 instances. In this mode, AWS NLB sends traffic to the instances and the kube-proxy on the individual worker nodes forward it to the pods through one or more worker nodes in the Kubernetes cluster.

The AWS Load Balancer Controller also supports creating NLBs operating in "IP mode". In this mode, the AWS NLB sends traffic directly to the Kubernetes pods behind the service, eliminating the need for an extra network hop through the worker nodes in the Kubernetes cluster. IP target mode supports pods running on both AWS EC2 instances and AWS Fargate.

# IP mode

The previous diagram explains how application traffic flows differently when the target group mode is instance and IP.

When the target group mode is instance, the traffic flows via a node port created for a service on each node. In this mode, kube-proxy routes the traffic to the pod running this service. The service pod could be running in a different node than the node that received the traffic from the load balancer. ServiceA (green) and ServiceB (pink) are configured to operate in "instance mode".

Alternatively, when the target group mode is IP, the traffic flows directly to the service pods from the load balancer. In this mode, we bypass a network hop of kube-proxy. ServiceC (blue) is configured to operate in "IP mode".

The numbers in the previous diagram represents the following things.

The EKS cluster where the services are deployed
The ELB instance exposing the service
The target group mode configuration that can be either instance or IP
The listener protocols configured for the load balancer on which the service is exposed
The target group rule configuration used to determine the service destination
There are several reasons why we might want to configure the NLB to operate in IP target mode:

It creates a more efficient network path for inbound connections, bypassing kube-proxy on the EC2 worker node
It removes the need to consider aspects such as externalTrafficPolicy and the trade-offs of its various configuration options
An application is running on Fargate instead of EC2
Re-configuring the NLB
Let's reconfigure our NLB to use IP mode and look at the effect it has on the infrastructure.

This is the patch we'll be applying to re-configure the Service:

Kustomize Patch
Service/ui-nlb
Diff
./exposing/load-balancer/ip-mode/nlb.yaml
apiVersion: v1
kind: Service
metadata:
  name: ui-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
  namespace: ui

Apply the manifest with kustomize:

kubectl apply -k ./exposing/load-balancer/ip-mode
It will take a few minutes for the configuration of the load balancer to be updated. Run the following command to ensure the annotation is updated:


$ kubectl describe service/ui-nlb -n ui
Name:                     ui-nlb
Namespace:                ui
Labels:                   <none>
Annotations:              service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
                          service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
                          service.beta.kubernetes.io/aws-load-balancer-type: external
Selector:                 app.kubernetes.io/component=service,app.kubernetes.io/instance=ui,app.kubernetes.io/name=ui
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.100.102.96
IPs:                      10.100.102.96
LoadBalancer Ingress:     k8s-ui-uinlb-34c0fa10fc-06598ddcf32d499c.elb.us-east-2.amazonaws.com
Port:                     http  80/TCP
TargetPort:               8080/TCP
NodePort:                 http  32452/TCP
Endpoints:                192.168.30.232:8080,192.168.51.42:8080,192.168.74.234:8080
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason                  Age   From     Message        
  ----    ------                  ----  ----     -------        
  Normal  SuccessfullyReconciled  22m   service  Successfully reconciled


# Ingress

Creates an IAM role required by the AWS Load Balancer Controller
You can view the Terraform that applies these changes here.

Kubernetes Ingress is an API resource that allows you to manage external or internal HTTP(S) access to Kubernetes services running in a cluster. Amazon Elastic Load Balancing Application Load Balancer (ALB) is a popular AWS service that load balances incoming traffic at the application layer (layer 7) across multiple targets, such as Amazon EC2 instances, in a region. ALB supports multiple features including host or path based routing, TLS (Transport Layer Security) termination, WebSockets, HTTP/2, AWS WAF (Web Application Firewall) integration, integrated access logs, and health checks.

In this lab exercise, we'll expose our sample application using an ALB with the Kubernetes ingress model.


Introduction
First lets install the AWS Load Balancer controller using helm:


see:

`./irsa.sh`

$ kubectl get ingress -n ui
No resources found in ui namespace.
There are also no Service resources of type LoadBalancer, which you can confirm with the following command:


$ kubectl get svc -n ui
NAME   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
ui     ClusterIP   10.100.221.103   <none>        80/TCP    29m


# Creating the Ingress
Let's create an Ingress resource with the following manifest:

./exposing/ingress/creating-ingress/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui
  namespace: ui
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health/liveness
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ui
                port:
                  number: 80


This will cause the AWS Load Balancer Controller to provision an Application Load Balancer and configure it to route traffic to the Pods for the ui application.


`kubectl apply -k ./exposing/ingress/creating-ingress`



# Multiple Ingress pattern
It's common to leverage multiple Ingress objects in the same EKS cluster, for example to expose multiple different workloads. By default each Ingress will result in the creation of a separate ALB, but we can leverage the IngressGroup feature which enables you to group multiple Ingress resources together. The controller will automatically merge Ingress rules for all Ingresses within IngressGroup and support them with a single ALB. In addition, most annotations defined on an Ingress only apply to the paths defined by that Ingress.

exposing the catalog API out through the same ALB as the ui component, leveraging path-based routing to dispatch requests to the appropriate Kubernetes service. Let's check we can't already access the catalog API:

./exposing/ingress/multiple-ingress/ingress-ui.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui
  namespace: ui
  labels:
    app.kubernetes.io/created-by: eks-workshop
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health/liveness
    alb.ingress.kubernetes.io/group.name: retail-app-group
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ui
                port:
                  number: 80


Now, let's create a separate Ingress for the catalog component that also leverages the same group.name:

./exposing/ingress/multiple-ingress/ingress-catalog.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: catalog
  namespace: catalog
  labels:
    app.kubernetes.io/created-by: eks-workshop
  annotations:
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/group.name: retail-app-group
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /catalogue
            pathType: Prefix
            backend:
              service:
                name: catalog
                port:
                  number: 80


This ingress is also configuring rules to route requests prefixed with /catalogue to the catalog component.

Apply these manifests to the cluster:


$ kubectl apply -k ./exposing/ingress/multiple-ingress

We'll now have two separate Ingress objects in our cluster:

~
$
kubectl get ingress -l app.kubernetes.io/created-by=eks-workshop -A
NAMESPACE   NAME      CLASS   HOSTS   ADDRESS                                                              PORTS   AGE
catalog     catalog   alb     *       k8s-retailappgroup-2c24c1c4bc-17962260.us-west-2.elb.amazonaws.com   80      2m21s
ui          ui        alb     *       k8s-retailappgroup-2c24c1c4bc-17962260.us-west-2.elb.amazonaws.com   80      2m21s


Notice that the ADDRESS of both are the same URL, which is because both of these Ingress objects are being grouped together behind the same ALB.

We can take a look at the ALB listener to see how this works:

~
$
ALB_ARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-retailappgroup`) == `true`].LoadBalancerArn' | jq -r '.[0]')
~
$
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN | jq -r '.Listeners[0].ListenerArn')
~
$
aws elbv2 describe-rules --listener-arn $LISTENER_ARN

The output of this command will illustrate that:

Requests with path prefix /catalogue will get sent to a target group for the catalog service
Everything else will get sent to a target group for the ui service

As a default backup there is a 404 for any requests that happen to fall through the cracks

You can also checkout out the new ALB configuration in the AWS console:

https://console.aws.amazon.com/ec2/home#LoadBalancers:tag:ingress.k8s.aws/stack=retail-app-group;sort=loadBalancerName

To wait until the load balancer has finished provisioning you can run this command:

~
$
wait-for-lb $(kubectl get ingress -n ui ui -o jsonpath="{.status.loadBalancer.ingress[*].hostname}{'\n'}")

Try accessing the new Ingress URL in the browser as before to check the web UI still works:

~
$
kubectl get ingress -n ui ui -o jsonpath="{.status.loadBalancer.ingress[*].hostname}{'\n'}"
k8s-ui-uinlb-a9797f0f61.elb.us-west-2.amazonaws.com

Now try accessing the specific path we directed to the catalog service:

~
$
ADDRESS=$(kubectl get ingress -n ui ui -o jsonpath="{.status.loadBalancer.ingress[*].hostname}{'\n'}")
~
$
curl $ADDRESS/catalogue | jq .

You'll receive back a JSON payload from the catalog service, demonstrating that we've been able to expose multiple Kubernetes services via the same ALB.

Edit this page

