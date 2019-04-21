#!/bin/bash

# Setting all parameters
NODE_TYPE=$1
INTERNAL=!$2
MASTER_IP=$3

## Parameters for master node installation
if [ "$NODE_TYPE" == "master" ]
then
	if [ "$#" -lt 4 ]; then
		POD_NETWORK_ARG=""
	else
		POD_NETWORK_ARG="--pod-network-cidr=$4"
	fi
# Parameters for worker node installation
elif [ "$NODE_TYPE" == "worker" ]
then
	TOKEN=$4
	HASH=$5
fi

#Installing Docker
DOCKER_INSTALLED=$(which docker)
if [ "$DOCKER_INSTALLED" = "" ]
then
	apt-get remove docker docker-engine docker.io
	apt-get update
	apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update
	apt-get install -y docker-ce
fi


#Installing Kubernetes
KUBERNETES_INSTALLED=$(which kubeadm)
if [ "$KUBERNETES_INSTALLED" = "" ]
then
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	touch /etc/apt/sources.list.d/kubernetes.list
	chmod 666 /etc/apt/sources.list.d/kubernetes.list
	echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
	apt-get update
	apt-get install -y kubelet kubeadm kubectl kubernetes-cni
fi

#Disabling swap for Kubernetes
sysctl net.bridge.bridge-nf-call-iptables=1 > /dev/null
swapoff -a

# Initialize Kubernetes as Master node
if [ "$NODE_TYPE" == "master" ]
then
	## Set master node for internal network
	if [ $INTERNAL ]; then
		touch /etc/default/kubelet
		echo "KUBELET_EXTRA_ARGS=--node-ip=$MASTER_IP" > /etc/default/kubelet
	fi
	## Init Kubernetes
	kubeadm init --ignore-preflight-errors=SystemVerification \
		--apiserver-advertise-address=$MASTER_IP $POD_NETWORK_ARG
	mkdir -p $HOME/.kube
	cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	chown $(id -u):$(id -g) $HOME/.kube/config

	echo "[master:$(hostname -s)] Node is up and running on $MASTER_IP"

# Initialize Kubernetes as Worker node
elif [ "$NODE_TYPE" = "worker" ]
then
	## Set worker node for internal network
	if [ $INTERNAL ]; then
		IP=$(grep -oP \
				'(?<=src )[^ ]*' \
				<(grep  -f <(ls -l /sys/class/net | grep pci | awk '{print $9}') \
					<(ip ro sh) |
				grep -v $(ip ro sh | grep default | awk '{print $5}')) |
			head -1)
		touch /etc/default/kubelet
		echo "KUBELET_EXTRA_ARGS=--node-ip=$IP" > /etc/default/kubelet
	else
		IP=$(grep -oP '(?<=src )[^ ]*' <(ip ro sh | grep default))
	fi
	## Join to Kubernetes Master node
	kubeadm join $MASTER_IP --token $TOKEN --discovery-token-ca-cert-hash $HASH \
		--ignore-preflight-errors=SystemVerification

	echo "[worker:$(hostname -s)] Client ($IP) joined to Master ($MASTER_IP)"
else
	echo "Invalid argument"
fi
