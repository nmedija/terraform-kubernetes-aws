#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

apt-get upgrade -y && apt-get update -y && apt-get install -y apt-transport-https
apt-get install -y docker.io

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update -y
apt-get install -y kubelet=1.13.3-00 kubeadm=1.13.3-00 kubectl=1.13.3-00
apt-mark hold kubelet kubeadm kubectl

kubeadm_token=$(kubeadm token generate)
kubeadm init --token="$kubeadm_token"
status=$?
if [ "$status" -eq 0 ]; then
  sysctl net.bridge.bridge-nf-call-iptables=1

  # setup weave net
  export KUBECONFIG=/etc/kubernetes/admin.conf
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

  # get discovery hash value
  kubeadm_hash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')

  echo "$kubeadm_token" > /tmp/.kubeadm_token
  echo "$kubeadm_hash" > /tmp/.kubeadm_hash

  mkdir -p /home/ubuntu/.kube
  cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  chown -R ubuntu:ubuntu /home/ubuntu/.kube
fi
exit "$status"
