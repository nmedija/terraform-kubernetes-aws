#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

ready() {
  pgrep -x "kubelet" > /dev/null
  status=$?
  if [ "$status" -eq 0 ] && [ -f "/tmp/.kubeadm_token" ] && [ -f "/tmp/.kubeadm_hash" ]; then
    echo "Y"
    return
  fi
  echo "N"
}

wait_until_done() {
  max_time="$1"
  interval="$2"
  total_time=0
  while [ "$total_time" -lt "$max_time" ]; do
    if [ "$(ready)" == "Y" ]; then
      break
    fi
    echo "Waiting until master node completed initializing..."
    sleep "$interval"
    total_time=$(( $total_time + $interval ))
  done
  if [[ "$total_time" -ge "$max_time" ]] && [[ "$(ready)" == "N" ]]; then
    return 1
  fi
  return 0
}

wait_until_done "$1" "$2"
