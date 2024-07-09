# Automation with GitOps (ArgoCD)

# GitOps
Companies want to go fast; they need to deploy more often, more reliably, and preferably with less overhead. GitOps is a fast and secure method for developers to manage and update complex applications and infrastructure running in Kubernetes.

GitOps is an operations and application deployment workflow and a set of best practices for managing both infrastructure and deployments for cloud-native applications. This post is divided into two parts. In the first part, we provide you with the history of GitOps as well as a description of how it works and what the benefits are. In the second part, you can try it out for yourself with a hands-on tutorial that describes how to set up a continuous deployment pipeline with Flux to Amazon Elastic Kubernetes Service (Amazon EKS).

What is GitOps? Coined by Weaveworks CEO, Alexis Richardson, GitOps is an operating model for Kubernetes and other cloud native technologies. It provides a set of best practices that unifies deployment, management, and monitoring for clusters and applications. Another way to put it is: a path towards a developer experience for managing applications; where end-to-end CI and CD pipelines and Git workflows are applied to both operations, and development.


# Argo CD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. Argo CD controller in Kubernetes cluster continuously monitors the state of your cluster and compares it with the desired state defined in Git. If the cluster state does not match the desired state, Argo CD reports the deviation and provides visualizations to help developers manually or automatically sync the cluster state with the desired state.

**Argo CD offers 3 ways to manage your application state:**

- CLI - A powerful CLI that lets you create YAML resource definitions for your applications and sync them with your cluster.

- User Interface - A web-based UI that lets you do the same things that you can do with the CLI. It also lets you visualize the Kubernetes resources belongs to the Argo CD applications that you create.
Kubernetes manifests and Helm charts applied to the cluster.


![argo-cd-architecture](https://github.com/ChukwuemekaAham/ArgoCD_EKS_Reskill/blob/main/base-application/argo-cd-architecture-58970cbaf9bfe2758e77c3739c218ad0.png)

# Installing Argo CD
First lets install Argo CD in our cluster:

```bash
helm repo add argo-cd https://argoproj.github.io/argo-helm

helm upgrade --install argocd argo-cd/argo-cd --version "${ARGOCD_CHART_VERSION}" \
  --namespace "argocd" --create-namespace \
  --values values.yaml \
  --wait

Release "argocd" does not exist. Installing it now.
NAME: argocd
LAST DEPLOYED: Sun Jul  7 15:07:26 2024
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:

# In order to access the server UI you have the following options:      

1. kubectl port-forward service/argocd-server -n argocd 8080:443      
    and then open the browser on http://localhost:8080 and accept the certificate

2. enable ingress in the values file `server.ingress.enabled` and either
    - Add the annotation for ssl passthrough: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-1-ssl-passthrough  

    - Set the `configs.params."server.insecure"` in the values file and terminate SSL at your ingress: https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#option-2-multiple-ingress-objects-and-hosts


# After reaching the UI the first time you can login with username: admin and the random password generated during the installation. You can find the password by running:

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

(You should delete the initial secret afterwards as suggested by the Getting Started Guide: https://argo-cd.readthedocs.io/en/stable/getting_started/#4-login-using-the-cli)

#the Argo CD server UI has been exposed outside of the cluster using Kubernetes Service of Load Balancer type. To get the URL from Argo CD service run the following command:

export ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname')

echo "ArgoCD URL: https://$ARGOCD_SERVER"

ArgoCD URL: https://adcd79e527dee469886b5ea62e290d2d-1300424303.us-east-2.elb.amazonaws.com

#The load balancer will take some time to provision so use this command to wait until ArgoCD responds:

curl --head -X GET --retry 20 --retry-all-errors --retry-delay 15 \
  --connect-timeout 5 --max-time 10 -k \
  https://$ARGOCD_SERVER


#The initial username is admin and the password is auto-generated. You can get it by running the following command:

export ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD admin password: $ARGOCD_PWD"
ArgoCD admin password: Nb4arW9Ew2ld8h8M

#Log in to the Argo CD UI using the URL and credentials you just obtained. You will be presented with a screen that looks like this:

#argocd-ui

#Argo CD also provides a powerful CLI tool called argocd that can be used to manage applications.

#INFO
#You can learn more about installing the CLI tool by following the https://argo-cd.readthedocs.io/en/stable/cli_installation/.

#In order to interact with Argo CD objects using CLI, we need to login to the Argo CD server by running the following commands:


argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PWD --insecure
'admin:login' logged in successfully
Context 'adcd79e527dee469886b5ea62e290d2d-1300424303.us-east-2.elb.amazonaws.com' updated



# Initial setup
#Argo CD applies the GitOps methodology to Kubernetes. It uses Git as a source of truth for your cluster's desired state. You can use Argo CD to deploy applications, monitor their health, and sync them with the desired state. 

# I deploy an applications specified in Kustomize using Argo CD. The UI application from EKS Workshop repository was used.

echo "# base-application" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/ChukwuemekaAham/base-application.git
git push -u origin main


#or push to existing repository
git remote add origin https://github.com/ChukwuemekaAham/base-application.git
git branch -M main
git push -u origin main

# A Git repository in AWS CodeCommit has already been created for you, let's clone it and do some initial set-up:

export GITOPS_REPO_URL_ARGOCD=https://github.com/ChukwuemekaAham/base-application.git

git clone $GITOPS_REPO_URL_ARGOCD 

git -C ./base-application checkout -b main
#Switched to a new branch 'main'

mkdir ./base-application/apps && touch base-application/apps/.gitkeep

git -C ./base-application add .

git -C ./base-application commit -am "Initial commit"

git -C ./base-application push --set-upstream origin main


# Validate Git Repository Access: Ensure that the ArgoCD instance can access the Git repository specified by the --repo flag. Verify that the Git repository URL is correct and that the necessary credentials (e.g., SSH keys, access tokens) are configured correctly in ArgoCD.

argocd repo list

argocd repo get <repo-url>

************************************************************************
# To configure ArgoCD to use a GitHub repository, you can follow these steps:

Create personal access token at the [New personal access page](https://github.com/settings/tokens/new) in GitHub


# Prepare the GitHub Repository:
# Create a new GitHub repository or use an existing one.
# Ensure that the repository contains the necessary Kubernetes manifests and configuration files for your application.
# Configure the GitHub Access Credentials in ArgoCD:
# In the ArgoCD UI, navigate to the "Settings" section and then to the "Repositories" tab.
# Click on the "Connect Repo Using HTTPS" or "Connect Repo Using SSH" button, depending on the authentication method you want to use.
# If using HTTPS:
# Enter the GitHub repository URL (e.g., https://github.com/your-username/your-repo.git).
# Provide the GitHub username and personal access token or password.
# If using SSH:
# Enter the GitHub repository URL (e.g., git@github.com:your-username/your-repo.git).
# Upload the SSH public key that ArgoCD will use to authenticate with the GitHub repository.
# Click "Connect" to save the repository configuration.

**************************************************************************

#Create an Argo CD secret to give access to the Git repository from Argo CD:


argocd repo add $GITOPS_REPO_URL_ARGOCD --ssh-private-key-path ${HOME}/.ssh/gitops_ssh.pem --insecure-ignore-host-key --upsert --name git-repo

Repository 'ssh://...' added

# Argo CD application is a CRD Kubernetes resource object representing a deployed application instance in an environment. It defines key information about the application, such as the application name, the Git repository, and the path to the Kubernetes manifests. The application resource also defines the desired state of the application, such as the target revision, the sync policy, and the health check policy.

# As the next step let's create an Argo CD Application which Sync with desired state in the Git repository:

argocd app create apps --repo $GITOPS_REPO_URL_ARGOCD \
  --path apps --dest-server https://kubernetes.default.svc

application 'apps' created

# Verify that the application has been created:

$ argocd app list
NAME         CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                     PATH  TARGET   
argocd/apps  https://kubernetes.default.svc  default    default  Synced  Healthy  Auto        <none>      https://github.com/ChukwuemekaAham/base-application.git  apps  HEAD


# We can also see this Application in the ArgoCD UI now:

# Application in the ArgoCD UI

# Alternatively, you can also interact with Argo CD objects in the cluster using the kubectl command:

$ kubectl get applications.argoproj.io -n argocd
NAME   SYNC STATUS   HEALTH STATUS
apps   Synced        Healthy



# Deploying an application
# We have successfully configured Argo CD on our cluster so now we can deploy an application. To demonstrate the difference between a GitOps-based delivery of an application and other methods, we'll migrate the UI component of the sample application which is currently using the kubectl apply -k approach to the new Argo CD deployment approach.

$ tree ./base-application:

.
└── apps
    ├── configMap.yaml
    ├── deployment.yaml
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── serviceAccount.yaml
    └── service.yaml

# 1 directory, 6 files

# Open the Argo CD UI and navigate to the apps application.

# Application in the ArgoCD UI

# Finally we can push our configuration to the Git repository:

git -C ./base-application add .
~
$
git -C ./base-application commit -am "Adding the UI service"
~
$
git -C ./base-application push

# Click Refresh and Sync in ArgoCD UI or use argocd CLI to Sync the application:


argocd app sync apps

# After a short period of time, the application should be in Synced state and the resources should be deployed, the UI should look like this:

# argocd-deploy-application

# That shows that Argo CD created the basic kustomization, and that it's in sync with the cluster.

# We've now successfully migrated the UI component to deploy using Argo CD, and any further changes pushed to the Git repository will be automatically reconciled to our EKS cluster.

# You should now have all the resources related to the UI services deployed. To verify, run the following commands:

$ kubectl get deployment -n ui ui
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     1/1     1            1           136m


$ kubectl get pod -n ui
NAME                 READY   STATUS    RESTARTS   AGE
ui-fddcf8d7b-pmn42   1/1     Running   0          136m


# Updating an application
# Now we can use Argo CD and Kustomize to deploy patches to our application manifests using GitOps

# For example, lets increase the number of replicas for ui deployment to 3

# You can execute commands to add necessary changes to the file apps/deployment.yaml:

$ yq -i '.spec.replicas = 3' ./base-application/apps/deployment.yaml

Push changes to the Git repository

$ git -C ./base-application add .

$ git -C ./base-application commit -am "Update UI service replicas"
[main bd644bf] Update UI service replicas
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git -C ./base-application push
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 4 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 380 bytes | 190.00 KiB/s, done.
Total 4 (delta 3), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (3/3), completed with 3 local objects.
To https://github.com/ChukwuemekaAham/base-application
   88eed4c..bd644bf  main -> main


# Click Refresh and Sync in ArgoCD UI or use argocd CLI to Sync the application:

$ argocd app sync apps

Name:               argocd/apps
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://argocd.example.com/applications/apps
Repo:               https://github.com/ChukwuemekaAham/base-application.git       
Target:             HEAD
Path:               apps
SyncWindow:         Sync Allowed
Sync Policy:        Automated
Sync Status:        Synced to HEAD (88eed4c)
Health Status:      Healthy

Operation:          Sync
Message:            successfully synced (all tasks run)

GROUP  KIND            NAMESPACE  NAME  STATUS   HEALTH   HOOK  MESSAGE
       Namespace       default    ui    Running  Synced         namespace/ui unchanged
       ServiceAccount  ui         ui    Synced                  serviceaccount/ui unchanged
       ConfigMap       ui         ui    Synced                  configmap/ui unchanged
       Service         ui         ui    Synced   Healthy        service/ui unchanged
apps   Deployment      ui         ui    Synced   Healthy        deployment.apps/ui configured
       Namespace                  ui    Synced


# We should have now 3 pods in ui deployment

# argocd-update-application

# To verify, run the following commands:

$ kubectl get deployment -n ui ui
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     3/3     3            3           164m  

$ kubectl get pod -n ui
NAME                 READY   STATUS    RESTARTS   AGE
ui-fddcf8d7b-2k95f   1/1     Running   0          
97s
ui-fddcf8d7b-pmn42   1/1     Running   0          
165m
ui-fddcf8d7b-sv5hf   1/1     Running   0          
97s


$ kubectl apply -k ./exposing/load-balancer/nlb
service/ui-nlb created



# App of Apps
Argo CD can deploy a set of applications to different environments (DEV, TEST, PROD ...) using base Kubernetes manifests for applications and customizations specific to an environment.

We can leverage Argo CD App of Apps pattern to implement this use case. This pattern allows us to specify one Argo CD Application that consists of other applications.

argo-cd-app-of-apps

We reference EKS Workshop Git repository as a Git repository with base manifests for your Kubernetes resources. This repository will contain an initial resource state for each application.

.
|-- manifests
| |-- assets
| |-- carts
| |-- catalog
| |-- checkout
| |-- orders
| |-- other
| |-- rabbitmq
| `-- ui

# This example shows how to use Helm to create a configuration for a particular, for example DEV, environment. A typical layout of a Git repository could be:

.
|-- app-of-apps
|   |-- ...
`-- apps-kustomization
    ...

# Setup
# Before we start to setup Argo CD applications, let's delete Argo CD Application which we created for ui:

$ argocd app delete apps --cascade -y

# We create templates for set of ArgoCD applications using DRY approach in Helm charts:

.
|-- app-of-apps
|   |-- Chart.yaml
|   |-- templates
|   |   |-- _application.yaml
|   |   `-- application.yaml
|   `-- values.yaml
`-- apps-kustomization
    ...

# Chart.yaml is a boiler-plate. templates contains a template file which will be used to create applications defined in values.yaml.

# values.yaml also contains values which are specific for a particular environment and which will be applied to all application templates.

# First, copy App of Apps configuration which we described above to the Git repository directory:

$ cp -R ./automation/gitops/argocd/app-of-apps ./base-application/

$ yq -i ".spec.source.repoURL = env(GITOPS_REPO_URL_ARGOCD)" ./base-application/app-of-apps/values.yaml

# Next, push changes to the Git repository:


$ git -C ./base-application add .
warning: in the working copy of 'app-of-apps/Chart.yaml', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'app-of-apps/templates/_application.yaml', LF will be replaced by CRLF the next time Git touches it       
warning: in the working copy of 'app-of-apps/templates/application.yaml', LF will be replaced by CRLF the next time Git touches it        
warning: in the working copy of 'app-of-apps/values.yaml', LF will be replaced by CRLF the next time Git touches it

$ git -C ./base-application commit -am "Adding App of Apps"
[main efdca81] Adding App of Apps
 4 files changed, 52 insertions(+)
 create mode 100644 app-of-apps/Chart.yaml
 create mode 100644 app-of-apps/templates/_application.yaml
 create mode 100644 app-of-apps/templates/application.yaml
 create mode 100644 app-of-apps/values.yaml

$ git -C ./base-application push
Enumerating objects: 9, done.
Counting objects: 100% (9/9), done.
Delta compression using up to 4 threads
Compressing objects: 100% (8/8), done.
Writing objects: 100% (8/8), 1.14 KiB | 292.00 KiB/s, done.
Total 8 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object. 
To https://github.com/ChukwuemekaAham/base-application
   bd644bf..efdca81  main -> main

# Finally, we need to create new Argo CD Application to support App of Apps pattern. We define a new path to Argo CD Application using --path app-of-apps.

# We also enable ArgoCD Application to automatically synchronize the state in the cluster with the configuration in the Git repository using --sync-policy automated

$
argocd app create apps --repo https://github.com/ChukwuemekaAham/base-application.git \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated --self-heal --auto-prune \
  --set-finalizer \
  --upsert \
  --path app-of-apps
  --project app-of-apps

 application 'apps' created
 
# The default Refresh interval is 3 minutes (180 seconds). You could change the interval by updating the timeout.reconciliation value in the argocd-cm ConfigMap. If the interval is to 0 then Argo CD will not poll Git repositories automatically and alternative methods such as webhooks and/or manual syncs should be used.

# For training purposes, let's set Refresh interval to 5 seconds and restart the ArgoCD application controller to deploy our changes faster:

$ kubectl patch configmap/argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"5s"}}'

$ kubectl -n argocd rollout restart deploy argocd-repo-server

$ kubectl -n argocd rollout status deploy/argocd-repo-server

$ kubectl -n argocd rollout restart statefulset argocd-application-controller

$ kubectl -n argocd rollout status statefulset argocd-application-controller 

# Open the Argo CD UI and navigate to the apps application.

argocd-ui-app-of-apps.png

# Click Refresh and Sync in ArgoCD UI, use argocd CLI to Sync the application or wait until automatic Sync will be finished:

$ argocd app sync apps

Name:               argocd/apps
Project:            default
Server:             https://kubernetes.default.svc
Namespace:
URL:                https://argocd.example.com/applications/apps     
Repo:               https://github.com/ChukwuemekaAham/base-application.git
Target:             HEAD
Path:               app-of-apps
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to HEAD (efdca81)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      efdca81c2a71664e28bd854103736d8fdc48019a
Phase:              Succeeded
Start:              2024-07-07 21:26:56 +0100 WAT
Finished:           2024-07-07 21:26:56 +0100 WAT
Duration:           0s
application.argoproj.io/other unchanged
argoproj.io  Application  argocd     orders    Synced                application.argoproj.io/orders unchanged
argoproj.io  Application  argocd     rabbitmq  Synced                application.argoproj.io/rabbitmq unchanged
argoproj.io  Application  argocd     carts     Synced                application.argoproj.io/carts unchanged
argoproj.io  Application  argocd     ui        Synced                application.argoproj.io/ui unchanged
argoproj.io  Application  argocd     checkout  Synced                application.argoproj.io/checkout unchanged
argoproj.io  Application  argocd     catalog   Synced                application.argoproj.io/catalog unchanged


# We have Argo CD App of Apps Application deployed and synced.

# Our applications, except Argo CD App of Apps Application, are in Unknown state because we didn't deploy their configuration yet.

argocd-ui-apps.png

# We will deploy application configurations for the applications in the next step.



# Deploying applications
# We have successfully configured Argo CD App of Apps, so now we can deploy an environment specific customization for the set of application.

# First let's remove the existing Applications so we can replace it:

~
$
kubectl delete -k ./base-application --ignore-not-found=true
namespace "assets" deleted
namespace "carts" deleted
namespace "catalog" deleted
namespace "checkout" deleted
namespace "orders" deleted
namespace "other" deleted
namespace "rabbitmq" deleted
namespace "ui" deleted
...
We will then need to create a customization for each application:

.
|-- app-of-apps
|   |-- ...
`-- apps-kustomization
    |-- assets
    |   `-- kustomization.yaml
    |-- carts
    |   `-- kustomization.yaml
    |-- catalog
    |   `-- kustomization.yaml
    |-- checkout
    |   `-- kustomization.yaml
    |-- orders
    |   `-- kustomization.yaml
    |-- other
    |   `-- kustomization.yaml
    |-- rabbitmq
    |   `-- kustomization.yaml
    `-- ui
        |-- deployment-patch.yaml
        `-- kustomization.yaml

./base-application/apps-kustomization/ui/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://github.com/aws-samples/eks-workshop-v2/manifests/base-application/ui?ref=stable
patches:
  - path: deployment-patch.yaml



# We define a path to base Kubernetes manifests for an application, in this case ui, using resources. We also define which configuration should be applied to ui application in EKS cluster using patches.

./base-application/apps-kustomization/ui/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ui
spec:
  replicas: 1


# We would like to have 1 replica for ui application. All other application will use configuration from base Kubernetes manifests.

# Copy files to the Git repository directory:

# final Git directory should now look like this. You can validate it by running tree ./base-application:

|-- app-of-apps
|   |-- Chart.yaml
|   |-- templates
|   |   |-- _application.yaml
|   |   `-- application.yaml
|   `-- values.yaml
|-- apps
|   ...
`-- apps-kustomization
    |-- assets
    |   `-- kustomization.yaml
    |-- carts
    |   `-- kustomization.yaml
    |-- catalog
    |   `-- kustomization.yaml
    |-- checkout
    |   `-- kustomization.yaml
    |-- orders
    |   `-- kustomization.yaml
    |-- other
    |   `-- kustomization.yaml
    |-- rabbitmq
    |   `-- kustomization.yaml
    `-- ui
        |-- deployment-patch.yaml
        `-- kustomization.yaml

12 directories, 19 files

Push changes to the Git repository:

$ git -C ./base-application add .

$ git -C ./base-application commit -am "Adding apps kustomization"

$ git -C ./base-application push

Click Refresh and Sync in ArgoCD UI, use argocd CLI to Sync the application or wait until automatic Sync will be finished:


$ argocd app sync apps

$ argocd app sync ui

$ argocd app sync apps

Name:               argocd/apps
Project:            default
Server:             https://kubernetes.default.svc        
Namespace:
URL:                https://argocd.example.com/applications/apps
Repo:               https://github.com/ChukwuemekaAham/base-application.git
Target:             HEAD
Path:               app-of-apps
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to HEAD (4410000)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      44100004bace7d921830b752bcc863ca7c0d4c15
Phase:              Succeeded
Start:              2024-07-07 21:44:43 +0100 WAT
Message:            successfully synced (all tasks run)

GROUP        KIND         NAMESPACE  NAME      STATUS  HEALTH  HOOK  MESSAGE     
argoproj.io  Application  argocd     assets    Synced                application.argoproj.io/assets unchanged
argoproj.io  Application  argocd     orders    Synced                application.argoproj.io/orders unchanged
argoproj.io  Application  argocd     ui        Synced                application.argoproj.io/ui unchanged
argoproj.io  Application  argocd     carts     Synced                application.argoproj.io/carts unchanged
argoproj.io  Application  argocd     checkout  Synced                application.argoproj.io/checkout unchanged
argoproj.io  Application  argocd     rabbitmq  Synced                application.argoproj.io/rabbitmq unchanged
argoproj.io  Application  argocd     catalog   Synced                application.argoproj.io/catalog unchanged
argoproj.io  Application  argocd     other     Synced                application.argoproj.io/other unchanged

$ argocd app sync ui

Name:               argocd/ui
Project:            default
Server:             https://kubernetes.default.svc
Namespace:
URL:                https://argocd.example.com/applications/ui
Repo:               https://github.com/ChukwuemekaAham/base-application.git      
Target:             main
Path:               apps-kustomization/ui
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (4410000)
Health Status:      Healthy

Operation:          Sync
Sync Revision:      44100004bace7d921830b752bcc863ca7c0d4c15
Phase:              Succeeded
Start:              2024-07-07 21:45:14 +0100 WAT
Finished:           2024-07-07 21:45:14 +0100 WAT
Duration:           0s
Message:            successfully synced (all tasks run)

GROUP  KIND            NAMESPACE  NAME  STATUS  HEALTH   HOOK  MESSAGE
       Namespace                  ui    Synced                 namespace/ui unchanged
       ServiceAccount  ui         ui    Synced                 serviceaccount/ui unchanged
       ConfigMap       ui         ui    Synced                 configmap/ui unchanged
       Service         ui         ui    Synced  Healthy        service/ui unchanged
apps   Deployment      ui         ui    Synced  Healthy        deployment.apps/ui configured


# We've now successfully migrated the all the applications to deploy using Argo CD, and any further changes pushed to the Git repository will be automatically reconciled to EKS cluster.

# When Argo CD finish the sync, all our applications will be in Synced state.

argocd-ui-apps.png

# You should also have all the resources related to the ui application deployed. To verify, run the following commands:


$ kubectl get deployment -n ui ui
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     1/1     1            1           6m12s

$ kubectl get pod -n ui
NAME                 READY   STATUS    RESTARTS   AGE
ui-fddcf8d7b-pfdgm   1/1     Running   0          9m16s


# Updating applications
Now we can use Argo CD and Kustomize to deploy patches to our application manifests using GitOps. For example, lets increase the number of replicas for ui deployment to 3.

# You can execute commands to add necessary changes to the file apps-kustomization/ui/deployment-patch.yaml:


$ yq -i '.spec.replicas = 3' ./base-application/apps-kustomization/ui/deployment-patch.yaml

# You can review planned changes in the file apps-kustomization/ui/deployment-patch.yaml.

Kustomize Patch
Deployment/ui
Diff

./base-application/update-application/deployment-patch.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ui
spec:
  replicas: 3

# Push changes to the Git repository:

$ git -C ./base-application add .
warning: in the working copy of 'apps-kustomization/ui/deployment-patch.yaml', LF will be replaced by CRLF the next time Git touches it

$ git -C ./base-application commit -am "Update UI service replicas"
[main 3fe097e] Update UI service replicas
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git -C ./base-application push
Enumerating objects: 9, done.
Counting objects: 100% (9/9), done.
Delta compression using up to 4 threads
Compressing objects: 100% (5/5), done.
Writing objects: 100% (5/5), 458 bytes | 229.00 KiB/s, done.
Total 5 (delta 3), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (3/3), completed with 3 local objects.
To https://github.com/ChukwuemekaAham/base-application
   4410000..3fe097e  main -> main

# Click Refresh and Sync in ArgoCD UI, use argocd CLI to Sync the application or wait until automatic Sync will be finished:


$ argocd app sync ui

argocd-update-application

To verify, run the following commands:

$ kubectl get deployment -n ui ui
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ui     3/3     3            3           3m33s


$ kubectl get pod -n ui
NAME                 READY   STATUS    RESTARTS   AGE
ui-fddcf8d7b-5tlm9   1/1     Running   0          3m2s
ui-fddcf8d7b-pcnhp   1/1     Running   0          3m2s
ui-fddcf8d7b-pfdgm   1/1     Running   0          17m


