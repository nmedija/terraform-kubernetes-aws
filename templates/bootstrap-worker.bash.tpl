#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

apt-get upgrade -y && apt-get update && apt-get install -y apt-transport-https
apt-get install -y docker.io

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update -y
apt-get install -y kubelet=1.13.3-00 kubeadm=1.13.3-00 kubectl=1.13.3-00
apt-mark hold kubelet kubeadm kubectl

sysctl net.bridge.bridge-nf-call-iptables=1

check_join_ready() {
  if [  -f "/tmp/kubeadm_join.bash" ] && [ -f "/tmp/.kubeadm_token" ] && [ -f "/tmp/.kubeadm_hash" ]; then
    echo "Y"
    return
  fi
  echo "N"
}

wait_until_ready() {
  max_time="$1"
  interval="$2"
  total_time=0
  while [ "$total_time" -lt "$max_time" ]; do
    if [ "$(check_join_ready)" == "Y" ]; then
      break
    fi
    echo "Waiting until master node completed initializing..."
    sleep "$interval"
    total_time=$(( $total_time + $interval ))
  done
  if [[ "$total_time" -ge "$max_time" ]] && [[ "$(check_join_ready)" == "N" ]]; then
    return 1
  fi
  return 0
}

wait_until_ready 600 10
status=$?
if [ "$status" -eq 0 ]; then
  chmod 755 /tmp/kubeadm_join.bash
  /tmp/kubeadm_join.bash
fi
