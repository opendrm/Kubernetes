# Kubernetes Cluster Deployer and Withdrawer

****

## Available CNI plugins (For now)

* Calico
* Cilium
* Flannel
* WeaveNet

****

## User's Manual

### Preparations
The commands must be run as root on the (future) master node. The SSH-key of the master node must be uploaded
on the worker node for root, so it can run seamlessly.

Create a `worker.list` file and add the hostname or the IP address of the worker nodes in it line-by-line
as you can see in the example file.

### Deploying Kubernetes Cluster
To install the cluster run the `./cluster-deploy [--external|-e] <CNI>` command. A Kubernetes CNI plugin name
must be given as an argument. If you give the word `help` as an argument, you will get the script usage
with the available CNI plugins.

