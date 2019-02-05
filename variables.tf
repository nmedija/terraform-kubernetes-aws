variable "aws_access_key" { }

variable "aws_secret_key" { }

variable "aws_region" {
  default = "us-east-1"
}

variable "kubernetes_version" {
  default = "1.13.3-*"
}

variable "master_node_hostname" {
  default = "kubemaster"
}

variable "worker_node_hostname" {
  default = "kubeworker"
}

variable "worker_nodes_count" {
  default = 1
}

variable "vpc_id" { }

variable "vpc_cidr" { }

variable "public_subnet_ids" {
  type = "list"
}

variable "private_subnet_ids" {
  type = "list"
}

variable "master_isntance_type" {
  default = "t3.small"
}

variable "worker_isntance_type" {
  default = "t3.small"
}

variable "ami" { }

variable "key_name" { }

variable "private_key_path" { }

variable "public_key_path" { }

variable "bastion_host" { }

variable "ssh_user" {
  default = "ubuntu"
}
