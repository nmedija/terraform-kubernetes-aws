#!/usr/bin/env bash

option="$1"

export TF_LOG='DEBUG'
export TF_LOG_PATH='./terraform.log'

command="terraform ${option}"

# Initialize
if [ ! -e  .terraform/terraform.tfstate ]; then
  terraform init terraform
fi

if [ -f "secret.tfvars" ]; then
  command="${command} -var-file=secret.tfvars"
fi

# kubeadm_token=$(./token)
# echo "Generated Token: $kubeadm_token"
# command="${command} -var=kubeadm_token=${kubeadm_token}"

shift 1
exec ${command} $@
