
# Storage
Storage on EKS will provide a high level overview on how to integrate two AWS Storage services with your EKS cluster.

Before we dive into the implementation, below is a summary of the two AWS storage services we'll utilize and integrate with EKS:

Amazon Elastic Block Store (supports EC2 only): a block storage service that provides direct access from EC2 instances and containers to a dedicated storage volume designed for both throughput and transaction-intensive workloads at any scale.
Amazon Elastic File System (supports Fargate and EC2): a fully managed, scalable, and elastic file system well suited for big data analytics, web serving and content management, application development and testing, media and entertainment workflows, database backups, and container storage. EFS stores your data redundantly across multiple Availability Zones (AZ) and offers low latency access from Kubernetes pods irrespective of the AZ in which they are running.
Amazon FSx for NetApp ONTAP (supports EC2 only): Fully managed shared storage built on NetApp’s popular ONTAP file system. FSx for NetApp ONTAP stores your data redundantly across multiple Availability Zones (AZ) and offers low latency access from Kubernetes pods irrespective of the AZ in which they are running.
FSx for Lustre (supports EC2 only): a fully managed, high-performance file system optimized for workloads such as machine learning, high-performance computing, video processing, financial modeling, electronic design automation, and analytics. With FSx for Lustre, you can quickly create a high-performance file system linked to your S3 data repository and transparently access S3 objects as files. FSx will be discussed in future modules of this workshop
It's also very important to be familiar with some concepts about Kubernetes Storage:

Volumes: On-disk files in a container are ephemeral, which presents some problems for non-trivial applications when running in containers. One problem is the loss of files when a container crashes. The kubelet restarts the container but with a clean state. A second problem occurs when sharing files between containers running together in a Pod. The Kubernetes volume abstraction solves both of these problems. Familiarity with Pods is suggested.
Ephemeral Volumes are designed for these use cases. Because volumes follow the Pod's lifetime and get created and deleted along with the Pod, Pods can be stopped and restarted without being limited to where some persistent volume is available.
Persistent Volumes (PV) is a piece of storage in a cluster that has been provisioned by an administrator or dynamically provisioned using Storage Classes. It's a resource in the cluster just like a node is a cluster resource. PVs are volume plugins like Volumes, but have a lifecycle independent of any individual Pod that uses the PV. This API object captures the details of the implementation of the storage, be that NFS, iSCSI, or a cloud-provider-specific storage system.
Persistent Volume Claim (PVC) is a request for storage by a user. It's similar to a Pod. Pods consume node resources and PVCs consume PV resources. Pods can request specific levels of resources (CPU and Memory). Claims can request specific size and access modes (e.g., they can be mounted ReadWriteOnce, ReadOnlyMany or ReadWriteMany, see AccessModes
Storage Classes provides a way for administrators to describe the "classes" of storage they offer. Different classes might map to quality-of-service levels, or to backup policies, or to arbitrary policies determined by cluster administrators. Kubernetes itself is unopinionated about what classes represent. This concept is sometimes called "profiles" in other storage systems.
Dynamic Volume Provisioning allows storage volumes to be created on-demand. Without dynamic provisioning, cluster administrators have to manually make calls to their cloud or storage provider to create new storage volumes, and then create PersistentVolume objects to represent them in Kubernetes. The dynamic provisioning feature eliminates the need for cluster administrators to pre-provision storage. Instead, it automatically provisions storage when it is requested by users.
On the following steps, we'll first integrate a Amazon EBS volume to be consumed by our MySQL database from the catalog microservice utilizing a statefulset object on Kubernetes. After that we'll integrate our component microservice filesystem to use the Amazon EFS shared file system, providing scalability, resiliency and more control over the files from our microservice.

Edit this page


# Amazon EBS
BEFORE YOU START
Prepare your environment for this section:

~
$
prepare-environment fundamentals/storage/ebs
This will make the following changes to your lab environment:

Create the IAM role needed for the EBS CSI driver addon
You can view the Terraform that applies these changes here.

Amazon Elastic Block Store is an easy-to-use, scalable, high-performance block-storage service. It provides persistent volume (non-volatile storage) to users. Persistent storage enables users to store their data until they decide to delete the data.

In this lab, we'll learn about the following concepts:

Kubernetes StatefulSets
EBS CSI Driver
StatefulSet with EBS Volume
Edit this page


StatefulSets

Like Deployments, StatefulSets manage Pods that are based on an identical container spec. Unlike Deployments, StatefulSets maintain a sticky identity for each of its Pods. These Pods are created from the same spec, but are not interchangeable with each having a persistent identifier that it maintains across any rescheduling event.

If you want to use storage volumes to provide persistence for your workload, you can use a StatefulSet as part of the solution. Although individual Pods in a StatefulSet are susceptible to failure, the persistent Pod identifiers make it easier to match existing volumes to the new Pods that replace any that have failed.

StatefulSets are valuable for applications that require one or more of the following:

Stable, unique network identifiers
Stable, persistent storage
Ordered, graceful deployment and scaling
Ordered, automated rolling updates
In our ecommerce application, we have a StatefulSet already deployed as part of the Catalog microservice. The Catalog microservice utilizes a MySQL database running on EKS. Databases are a great example for the use of StatefulSets because they require persistent storage. We can analyze our MySQL Database Pod to see its current volume configuration:

~
$
kubectl describe statefulset -n catalog catalog-mysql
Name:               catalog-mysql
Namespace:          catalog
[...]
  Containers:
   mysql:
    Image:      public.ecr.aws/docker/library/mysql:8.0
    Port:       3306/TCP
    Host Port:  0/TCP
    Environment:
      MYSQL_ROOT_PASSWORD:  my-secret-pw
      MYSQL_USER:           <set to the key 'username' in secret 'catalog-db'>  Optional: false
      MYSQL_PASSWORD:       <set to the key 'password' in secret 'catalog-db'>  Optional: false
      MYSQL_DATABASE:       <set to the key 'name' in secret 'catalog-db'>      Optional: false
    Mounts:
      /var/lib/mysql from data (rw)
  Volumes:
   data:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:
    SizeLimit:  <unset>
Volume Claims:  <none>
[...]
As you can see the Volumes section of our StatefulSet shows that we're only using an EmptyDir volume type which "shares the Pod's lifetime".

MySQL with emptyDir

An emptyDir volume is first created when a Pod is assigned to a node, and exists as long as that Pod is running on that node. As the name implies, the emptyDir volume is initially empty. All containers in the Pod can read and write the same files in the emptyDir volume, though that volume can be mounted on the same or different paths in each container. When a Pod is removed from a node for any reason, the data in the emptyDir is deleted permanently. Therefore EmptyDir is not a good fit for our MySQL Database.

We can demonstrate this by starting a shell session inside the MySQL container and creating a test file. After that we'll delete the Pod that is running in our StatefulSet. Because the pod is using an emptyDir and not a Persistent Volume (PV), the file will not survive a Pod restart. First let's run a command inside our MySQL container to create a file in the emptyDir /var/lib/mysql path (where MySQL saves database files):

~
$
kubectl exec catalog-mysql-0 -n catalog -- bash -c  "echo 123 > /var/lib/mysql/test.txt"
Now, let's verify our test.txt file was created in the /var/lib/mysql directory:

~
$
kubectl exec catalog-mysql-0 -n catalog -- ls -larth /var/lib/mysql/ | grep -i test
-rw-r--r-- 1 root  root     4 Oct 18 13:38 test.txt
Now, let's remove the current catalog-mysql Pod. This will force the StatefulSet controller to automatically re-create a new catalog-mysql Pod:

~
$
kubectl delete pods -n catalog -l app.kubernetes.io/component=mysql
pod "catalog-mysql-0" deleted
Wait for a few seconds and run the command below to check if the catalog-mysql Pod has been re-created:

~
$
kubectl wait --for=condition=Ready pod -n catalog \
  -l app.kubernetes.io/component=mysql --timeout=30s
pod/catalog-mysql-0 condition met
~
$
kubectl get pods -n catalog -l app.kubernetes.io/component=mysql
NAME              READY   STATUS    RESTARTS   AGE
catalog-mysql-0   1/1     Running   0          29s
Finally, let's exec back into the MySQL container shell and run a ls command in the /var/lib/mysql path to look for the test.txt file that was previously created:

~
$
kubectl exec catalog-mysql-0 -n catalog -- cat /var/lib/mysql/test.txt
cat: /var/lib/mysql/test.txt: No such file or directory
command terminated with exit code 1
As you can see the test.txt file no longer exists due to emptyDir volumes being ephemeral. In future sections, we'll run the same experiment and demostrate how Persistent Volumes (PVs) will persist the test.txt file and survive Pod restarts and/or failures.

On the next page, we'll work on understanding the main concepts of Storage on Kubernetes and its integration with the AWS cloud ecosystem.

Edit this page
Previous


# EBS CSI Driver
Before we dive into this section, make sure to familiarized yourself with the Kubernetes storage objects (volumes, persistent volumes (PV), persistent volume claim (PVC), dynamic provisioning and ephemeral storage) that were introduced on the Storage main section.

emptyDir is an example of ephemeral volumes, and we're currently utilizing it on the MySQL StatefulSet, but we'll work on updating it on this chapter to a Persistent Volume (PV) using Dynamic Volume Provisioning.

The Kubernetes Container Storage Interface (CSI) helps you run stateful containerized applications. CSI drivers provide a CSI interface that allows Kubernetes clusters to manage the lifecycle of persistent volumes. Amazon EKS makes it easier for you to run stateful workloads by offering CSI drivers for Amazon EBS.

In order to utilize Amazon EBS volumes with dynamic provisioning on our EKS cluster, we need to confirm that we have the EBS CSI Driver installed. The Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver allows Amazon Elastic Kubernetes Service (Amazon EKS) clusters to manage the lifecycle of Amazon EBS volumes for persistent volumes.

To improve security and reduce the amount of work, you can manage the Amazon EBS CSI driver as an Amazon EKS add-on. The IAM role needed by the addon was created for us so we can go ahead and install the addon:

~
$
aws eks create-addon --cluster-name $EKS_CLUSTER_NAME --addon-name aws-ebs-csi-driver \
  --service-account-role-arn $EBS_CSI_ADDON_ROLE
~
$
aws eks wait addon-active --cluster-name $EKS_CLUSTER_NAME --addon-name aws-ebs-csi-driver
Now we can take a look at what has been created in our EKS cluster by the addon. For example, a DaemonSet will be running a pod on each node in our cluster:

~
$
kubectl get daemonset ebs-csi-node -n kube-system
NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
ebs-csi-node   3         3         3       3            3           kubernetes.io/os=linux   3d21h
We also already have our StorageClass object configured using Amazon EBS GP2 volume type. Run the following command to confirm:

~
$
kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  3d22h
Now that we have a better understanding of EKS Storage and Kubernetes objects. On the next page, we'll focus on modifying the MySQL DB StatefulSet of the catalog microservice to utilize a EBS block store volume as the persistent storage for the database files using Kubernetes dynamic volume provisioning.

Edit this page


# StatefulSet with EBS Volume
Now that we understand StatefulSets and Dynamic Volume Provisioning, let's change our MySQL DB on the Catalog microservice to provision a new EBS volume to store database files persistent.

MySQL with EBS

Utilizing Kustomize, we'll do two things:

Create a new StatefulSet for the MySQL database used by the catalog component which uses an EBS volume
Update the catalog component to use this new version of the database
INFO
Why are we not updating the existing StatefulSet? The fields we need to update are immutable and cannot be changed.

Here in the new catalog database StatefulSet:

~/environment/eks-workshop/modules/fundamentals/storage/ebs/statefulset-mysql.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: catalog-mysql-ebs
  namespace: catalog
  labels:
    app.kubernetes.io/created-by: eks-workshop
    app.kubernetes.io/team: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/instance: catalog
      app.kubernetes.io/component: mysql-ebs
  serviceName: mysql
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
        app.kubernetes.io/instance: catalog
        app.kubernetes.io/component: mysql-ebs
        app.kubernetes.io/created-by: eks-workshop
        app.kubernetes.io/team: database
    spec:
      containers:
        - name: mysql
          image: "public.ecr.aws/docker/library/mysql:8.0"
          imagePullPolicy: IfNotPresent
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: my-secret-pw
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: catalog-db
                  key: username
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: catalog-db
                  key: password
            - name: MYSQL_DATABASE
              value: catalog
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp2
        resources:
          requests:
            storage: 30Gi


Notice the volumeClaimTemplates field which specifies the instructs Kubernetes to utilize Dynamic Volume Provisioning to create a new EBS Volume, a PersistentVolume (PV) and a PersistentVolumeClaim (PVC) all automatically.

This is how we'll re-configure the catalog component itself to use the new StatefulSet:

Kustomize Patch
Deployment/catalog
Diff
~/environment/eks-workshop/modules/fundamentals/storage/ebs/deployment.yaml
- op: add
  path: /spec/template/spec/containers/0/env/-
  value:
    name: DB_ENDPOINT
    value: catalog-mysql-ebs:3306

Apply the changes and wait for the new Pods to be rolled out:

~
$
kubectl apply -k ~/environment/eks-workshop/modules/fundamentals/storage/ebs/
~
$
kubectl rollout status --timeout=100s statefulset/catalog-mysql-ebs -n catalog
Let's now confirm that our newly deployed StatefulSet is running:

~
$
kubectl get statefulset -n catalog catalog-mysql-ebs
NAME                READY   AGE
catalog-mysql-ebs   1/1     79s
Inspecting our catalog-mysql-ebs StatefulSet, we can see that now we have a PersistentVolumeClaim attached to it with 30GiB and with storageClassName of gp2.

~
$
kubectl get statefulset -n catalog catalog-mysql-ebs \
  -o jsonpath='{.spec.volumeClaimTemplates}' | jq .
[
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "creationTimestamp": null,
      "name": "data"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "30Gi"
        }
      },
      "storageClassName": "gp2",
      "volumeMode": "Filesystem"
    },
    "status": {
      "phase": "Pending"
    }
  }
]
We can analyze how the Dynamic Volume Provisioning created a PersistentVolume (PV) automatically for us:

~
$
kubectl get pv | grep -i catalog
pvc-1df77afa-10c8-4296-aa3e-cf2aabd93365   30Gi       RWO            Delete           Bound         catalog/data-catalog-mysql-ebs-0          gp2                            10m
Utilizing the AWS CLI, we can check the Amazon EBS volume that got created automatically for us:

~
$
aws ec2 describe-volumes \
    --filters Name=tag:kubernetes.io/created-for/pvc/name,Values=data-catalog-mysql-ebs-0 \
    --query "Volumes[*].{ID:VolumeId,Tag:Tags}" \
    --no-cli-pager
If you prefer you can also check it via the AWS console, just look for the EBS volumes with the tag of key kubernetes.io/created-for/pvc/name and value of data-catalog-mysql-ebs-0:

EBS Volume AWS Console Screenshot

If you'd like to inspect the container shell and check out the newly EBS volume attached to the Linux OS, run this instructions to run a shell command into the catalog-mysql-ebs container. It'll inspect the file-systems that you have mounted:

~
$
kubectl exec --stdin catalog-mysql-ebs-0  -n catalog -- bash -c "df -h"
Filesystem      Size  Used Avail Use% Mounted on
overlay         100G  7.6G   93G   8% /
tmpfs            64M     0   64M   0% /dev
tmpfs           3.8G     0  3.8G   0% /sys/fs/cgroup
/dev/nvme0n1p1  100G  7.6G   93G   8% /etc/hosts
shm              64M     0   64M   0% /dev/shm
/dev/nvme1n1     30G  211M   30G   1% /var/lib/mysql
tmpfs           7.0G   12K  7.0G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           3.8G     0  3.8G   0% /proc/acpi
tmpfs           3.8G     0  3.8G   0% /sys/firmware

Check the disk that is currently being mounted on the /var/lib/mysql. This is the EBS Volume for the stateful MySQL database files that being stored in a persistent way.

Let's now test if our data is in fact persistent. We'll create the same test.txt file exactly the same way as we did on the first section of this module:

~
$
kubectl exec catalog-mysql-ebs-0 -n catalog -- bash -c  "echo 123 > /var/lib/mysql/test.txt"
Now, let's verify that our test.txt file got created on the /var/lib/mysql directory:

~
$
kubectl exec catalog-mysql-ebs-0 -n catalog -- ls -larth /var/lib/mysql/ | grep -i test
-rw-r--r-- 1 root  root     4 Oct 18 13:57 test.txt
Now, let's remove the current catalog-mysql-ebs Pod, which will force the StatefulSet controller to automatically re-create it:

~
$
kubectl delete pods -n catalog catalog-mysql-ebs-0
pod "catalog-mysql-ebs-0" deleted
Wait for a few seconds, and run the command below to check if the catalog-mysql-ebs Pod has been re-created:

~
$
kubectl wait --for=condition=Ready pod -n catalog \
  -l app.kubernetes.io/component=mysql-ebs --timeout=60s
pod/catalog-mysql-ebs-0 condition met
~
$
kubectl get pods -n catalog -l app.kubernetes.io/component=mysql-ebs
NAME                  READY   STATUS    RESTARTS   AGE
catalog-mysql-ebs-0   1/1     Running   0          29s
Finally, let's exec back into the MySQL container shell and run a ls command on the /var/lib/mysql path trying to look for the test.txt file that we created, and see if the file has now persisted:

~
$
kubectl exec catalog-mysql-ebs-0 -n catalog -- ls -larth /var/lib/mysql/ | grep -i test
-rw-r--r-- 1 mysql root     4 Oct 18 13:57 test.txt
~
$
kubectl exec catalog-mysql-ebs-0 -n catalog -- cat /var/lib/mysql/test.txt
123
As you can see the test.txt file is still available after a Pod delete and restart and with the right text on it 123. This is the main functionality of Persistent Volumes (PVs). Amazon EBS is storing the data and keeping our data safe and available within an AWS availability zone.

Edit this page



# Amazon EFS
BEFORE YOU START
Prepare your environment for this section:

~
$
prepare-environment fundamentals/storage/efs
This will make the following changes to your lab environment:

Create an IAM role for the Amazon EFS CSI driver
Create an Amazon EFS file system
You can view the Terraform that applies these changes here.

Amazon Elastic File System is a simple, serverless, set-and-forget elastic file system for use with AWS Cloud services and on-premises resources. It's built to scale on demand to petabytes without disrupting applications, growing and shrinking automatically as you add and remove files, eliminating the need to provision and manage capacity to accommodate growth.

In this lab, we'll learn about the following concepts:

Assets microservice deployment
EFS CSI Driver
Dynamic provisioning using EFS and a Kubernetes deployment
Edit this page

# Persistent network storage
On our ecommerce application, we have a deployment already created as part of our assets microservice. The assets microservice utilizes a webserver running on EKS. Web servers are a great example for the use of deployments because they scale horizontally and declare the new state of the Pods.

Assets component is a container which serves static images for products, these product images are added as part of the container image build. However with this setup every time the team wants to update the product images they have to recreate and redeploy the container image. In this exercise we'll utilize EFS File System and Kubernetes Persistent Volume to update old product images and add new product images without the need to rebuild the containers images.

We can start by describing the Deployment to take a look at its initial volume configuration:

~
$
kubectl describe deployment -n assets
Name:                   assets
Namespace:              assets
[...]
  Containers:
   assets:
    Image:      public.ecr.aws/aws-containers/retail-store-sample-assets:0.4.0
    Port:       8080/TCP
    Host Port:  0/TCP
    Limits:
      memory:  128Mi
    Requests:
      cpu:     128m
      memory:  128Mi
    Liveness:  http-get http://:8080/health.html delay=30s timeout=1s period=3s #success=1 #failure=3
    Environment Variables from:
      assets      ConfigMap  Optional: false
    Environment:  <none>
    Mounts:
      /tmp from tmp-volume (rw)
  Volumes:
   tmp-volume:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     Memory
    SizeLimit:  <unset>
[...]
As you can see the Volumes section of our Deployment shows that we're only using an EmptyDir volume type which "shares the Pod's lifetime".

Assets with emptyDir

An emptyDir volume is first created when a Pod is assigned to a node, and exists as long as that Pod is running on that node. As the name says, the emptyDir volume is initially empty. All containers in the Pod can read and write the same files in the emptyDir volume, though that volume can be mounted at the same or different paths in each container. When a Pod is removed from a node for any reason, the data in the emptyDir is deleted permanently. This means that if we want to share data between multiple Pods in the same Deployment and make changes to that data then EmptyDir is not a good fit.

The container has some initial product images copied to it as part of the container build under the folder /usr/share/nginx/html/assets, we can check by running the below command:

~
$
kubectl exec --stdin deployment/assets \
  -n assets -- bash -c "ls /usr/share/nginx/html/assets/"
chrono_classic.jpg
gentleman.jpg
pocket_watch.jpg
smart_1.jpg
smart_2.jpg
wood_watch.jpg
First lets scale up the assets Deployment so it has multiple replicas:

~
$
kubectl scale -n assets --replicas=2 deployment/assets
~
$
kubectl rollout status -n assets deployment/assets --timeout=60s
Now let us try to put a new product image named newproduct.png in the directory /usr/share/nginx/html/assets of the first Pod using the below command:

~
$
POD_NAME=$(kubectl -n assets get pods -o jsonpath='{.items[0].metadata.name}')
~
$
kubectl exec --stdin $POD_NAME \
  -n assets -- bash -c 'touch /usr/share/nginx/html/assets/newproduct.png'
Now confirm the new product image newproduct.png isn't present on the file system of the second Pod:

~
$
POD_NAME=$(kubectl -n assets get pods -o jsonpath='{.items[1].metadata.name}')
~
$
kubectl exec --stdin $POD_NAME \
  -n assets -- bash -c 'ls /usr/share/nginx/html/assets'
As you see the newly created image newproduct.png does not exist on the second Pod. In order to help solve this issue we need a file system that can be shared across multiple Pods if the service needs to scale horizontally while still making updates to the files without re-deploying.

Assets with EFS

Edit this page


# EFS CSI Driver
Before we dive into this section, make sure to familiarized yourself with the Kubernetes storage objects (volumes, persistent volumes (PV), persistent volume claim (PVC), dynamic provisioning and ephemeral storage) that were introduced on the Storage main section.

The Amazon Elastic File System Container Storage Interface (CSI) Driver helps you run stateful containerized applications. Amazon EFS Container Storage Interface (CSI) driver provide a CSI interface that allows Kubernetes clusters running on AWS to manage the lifecycle of Amazon EFS file systems.

In order to utilize Amazon EFS file system with dynamic provisioning on our EKS cluster, we need to confirm that we have the EFS CSI Driver installed. The Amazon Elastic File System Container Storage Interface (CSI) Driver implements the CSI specification for container orchestrators to manage the lifecycle of Amazon EFS file systems.

To improve security and reduce the amount of work, you can manage the Amazon EFS CSI driver as an Amazon EKS add-on. The IAM role needed by the add-on was created for us so we can go ahead and install the add-on:

~
$
aws eks create-addon --cluster-name $EKS_CLUSTER_NAME --addon-name aws-efs-csi-driver \
  --service-account-role-arn $EFS_CSI_ADDON_ROLE
~
$
aws eks wait addon-active --cluster-name $EKS_CLUSTER_NAME --addon-name aws-efs-csi-driver
Now we can take a look at what has been created in our EKS cluster by the addon. For example, a DaemonSet will be running a pod on each node in our cluster:

~
$
kubectl get daemonset efs-csi-node -n kube-system
NAME           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR                 AGE
efs-csi-node   3         3         3       3            3           kubernetes.io/os=linux        47s
The EFS CSI driver supports dynamic and static provisioning. Currently dynamic provisioning creates an access point for each PersistentVolume. This mean an AWS EFS file system has to be created manually on AWS first and should be provided as an input to the StorageClass parameter. For static provisioning, AWS EFS file system needs to be created manually on AWS first. After that it can be mounted inside a container as a volume using the driver.

We have provisioned an EFS file system, mount targets and the required security group pre-provisioned with an inbound rule that allows inbound NFS traffic for your Amazon EFS mount points. Let's retrieve some information about it that will be used later:

~
$
export EFS_ID=$(aws efs describe-file-systems --query "FileSystems[?Name=='$EKS_CLUSTER_NAME-efs-assets'] | [0].FileSystemId" --output text)
~
$
echo $EFS_ID
fs-061cb5c5ed841a6b0
Now, we'll need to create a StorageClass(https://kubernetes.io/docs/concepts/storage/storage-classes/) object configured to use the pre-provisioned EFS file system as part of this workshop infrastructure and use EFS Access points in provisioning mode.

We'll be using Kustomize to create for us the storage class and to ingest the environment variable EFS_ID in the parameter filesystemid value in the configuration of the storage class object:

~/environment/eks-workshop/modules/fundamentals/storage/efs/storageclass/efsstorageclass.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${EFS_ID}
  directoryPerms: "700"


Let's apply this kustomization:

~
$
kubectl kustomize ~/environment/eks-workshop/modules/fundamentals/storage/efs/storageclass \
  | envsubst | kubectl apply -f-
storageclass.storage.k8s.io/efs-sc created
Now we'll get and describe the StorageClass using the below commands. Notice that the provisioner used is the EFS CSI driver and the provisioning mode is EFS access point and ID of the file system as exported in the EFS_ID environment variable.

~
$
kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
efs-sc          efs.csi.aws.com         Delete          Immediate              false                  8m29s
~
$
kubectl describe sc efs-sc
Name:            efs-sc
IsDefaultClass:  No
Annotations:     kubectl.kubernetes.io/last-applied-configuration={"apiVersion":"storage.k8s.io/v1","kind":"StorageClass","metadata":{"annotations":{},"name":"efs-sc"},"parameters":{"directoryPerms":"700","fileSystemId":"fs-061cb5c5ed841a6b0","provisioningMode":"efs-ap"},"provisioner":"efs.csi.aws.com"}
Provisioner:           efs.csi.aws.com
Parameters:            directoryPerms=700,fileSystemId=fs-061cb5c5ed841a6b0,provisioningMode=efs-ap
AllowVolumeExpansion:  <unset>
MountOptions:          <none>
ReclaimPolicy:         Delete
VolumeBindingMode:     Immediate
Events:                <none>
Now that we have a better understanding of EKS StorageClass and EFS CSI driver. On the next page, we'll focus on modifying the asset microservice to leverage the EFS StorageClass using Kubernetes dynamic volume provisioning and a PersistentVolume to store the product images.

Edit this page

*************************************************************************
# Dynamic provisioning using EFS

Now that we understand the EFS storage class for Kubernetes let's create a Persistent Volume and change the assets container on the assets deployment to mount the Volume created.

First inspect the efspvclaim.yaml file to see the parameters in the file and the claim of the specific storage size of 5GB from the Storage class efs-sc we created in the earlier step:

~/environment/eks-workshop/modules/fundamentals/storage/efs/deployment/efspvclaim.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
  namespace: assets
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi


We'll also modify the assets service in two ways:

Mount the PVC to the location where the assets images are stored
Add an init container to copy the initial images to the EFS volume
Kustomize Patch
Deployment/assets
Diff
~/environment/eks-workshop/modules/fundamentals/storage/efs/deployment/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: assets
spec:
  replicas: 2
  template:
    spec:
      initContainers:
        - name: copy
          image: "public.ecr.aws/aws-containers/retail-store-sample-assets:0.4.0"
          command:
            ["/bin/sh", "-c", "cp -R /usr/share/nginx/html/assets/* /efsvolume"]
          volumeMounts:
            - name: efsvolume
              mountPath: /efsvolume
      containers:
        - name: assets
          volumeMounts:
            - name: efsvolume
              mountPath: /usr/share/nginx/html/assets
      volumes:
        - name: efsvolume
          persistentVolumeClaim:
            claimName: efs-claim

We can apply the changes by running the following command:

~
$
kubectl apply -k ~/environment/eks-workshop/modules/fundamentals/storage/efs/deployment
namespace/assets unchanged
serviceaccount/assets unchanged
configmap/assets unchanged
service/assets unchanged
persistentvolumeclaim/efs-claim created
deployment.apps/assets configured
~
$
kubectl rollout status --timeout=130s deployment/assets -n assets
Now look at the volumeMounts in the deployment, notice that we have our new Volume named efsvolume mounted onvolumeMounts named /usr/share/nginx/html/assets:

~
$
kubectl get deployment -n assets \
  -o yaml | yq '.items[].spec.template.spec.containers[].volumeMounts'
- mountPath: /usr/share/nginx/html/assets
  name: efsvolume
- mountPath: /tmp
  name: tmp-volume
A PersistentVolume (PV) has been created automatically for the PersistentVolumeClaim (PVC) we had created in the previous step:

~
$
kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                 STORAGECLASS   REASON   AGE
pvc-342a674d-b426-4214-b8b6-7847975ae121   5Gi        RWX            Delete           Bound    assets/efs-claim                      efs-sc                  2m33s
Also describe the PersistentVolumeClaim (PVC) created:

~
$
kubectl describe pvc -n assets
Name:          efs-claim
Namespace:     assets
StorageClass:  efs-sc
Status:        Bound
Volume:        pvc-342a674d-b426-4214-b8b6-7847975ae121
Labels:        <none>
Annotations:   pv.kubernetes.io/bind-completed: yes
               pv.kubernetes.io/bound-by-controller: yes
               volume.beta.kubernetes.io/storage-provisioner: efs.csi.aws.com
               volume.kubernetes.io/storage-provisioner: efs.csi.aws.com
Finalizers:    [kubernetes.io/pvc-protection]
Capacity:      5Gi
Access Modes:  RWX
VolumeMode:    Filesystem
Used By:       <none>
Events:
  Type    Reason                 Age   From                                                                                      Message
  ----    ------                 ----  ----                                                                                      -------
  Normal  ExternalProvisioning   34s   persistentvolume-controller                                                               waiting for a volume to be created, either by external provisioner "efs.csi.aws.com" or manually created by system administrator
  Normal  Provisioning           34s   efs.csi.aws.com_efs-csi-controller-6b4ff45b65-fzqjb_7efe91cc-099a-45c7-8419-6f4b0a4f9e01  External provisioner is provisioning volume for claim "assets/efs-claim"
  Normal  ProvisioningSucceeded  33s   efs.csi.aws.com_efs-csi-controller-6b4ff45b65-fzqjb_7efe91cc-099a-45c7-8419-6f4b0a4f9e01  Successfully provisioned volume pvc-342a674d-b426-4214-b8b6-7847975ae121
Now create a new file newproduct.png under the assets directory in the first Pod:

~
$
POD_NAME=$(kubectl -n assets get pods -o jsonpath='{.items[0].metadata.name}')
~
$
kubectl exec --stdin $POD_NAME \
  -n assets -c assets -- bash -c 'touch /usr/share/nginx/html/assets/newproduct.png'
And verify that the file now also exists in the second Pod:

~
$
POD_NAME=$(kubectl -n assets get pods -o jsonpath='{.items[1].metadata.name}')
~
$
kubectl exec --stdin $POD_NAME \
  -n assets -c assets -- bash -c 'ls /usr/share/nginx/html/assets'
chrono_classic.jpg
gentleman.jpg
newproduct.png <-----------
pocket_watch.jpg
smart_1.jpg
smart_2.jpg
test.txt
wood_watch.jpg
Now as you can see even though we created a file through the first Pod the second Pod also has access to this file because of the shared EFS file system.

Edit this page