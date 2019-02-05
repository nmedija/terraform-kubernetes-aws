#!/usr/bin/env bash

set -o errexit

kubeadm_token="$(cat /tmp/.kubeadm_token)"
kubeadm_hash="$(cat /tmp/.kubeadm_hash)"

kubeadm join ${master_host}:${master_port} \
  --token $kubeadm_token \
  --discovery-token-ca-cert-hash sha256:$kubeadm_hash
