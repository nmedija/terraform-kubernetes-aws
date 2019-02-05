provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"

  version = "~> 1.56"
}

# ----------------------
# Create security groups
# ----------------------

resource "aws_security_group" "sg_kubemaster" {
  name = "sg_kubemaster"
  description = "Security Group for Kubernetes Master"
  vpc_id = "${var.vpc_id}"

  ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ "${var.vpc_cidr}" ]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [ "${var.vpc_cidr}" ]
  }

  egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [ "0.0.0.0/0" ]
  }
}

resource "aws_security_group" "sg_kubeworker" {
    name        = "sg_kubeworker"
    description = "Security Group for Kubernetes Worker"
    vpc_id = "${var.vpc_id}"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [ "${var.vpc_cidr}" ]
    }

    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [ "${var.vpc_cidr}" ]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
}

# --------------------------------------
# Create master / control plane instance
# --------------------------------------

data "template_file" "bootstrap_master" {
  template = "${file("${path.module}/templates/bootstrap-master.bash.tpl")}"
  vars {
    kubernetes_version="${var.kubernetes_version}"
  }
}

resource "aws_instance" "kube_master" {
  ami = "${var.ami}"
  instance_type = "${var.master_isntance_type}"
  subnet_id = "${element(var.private_subnet_ids, 0)}"
  associate_public_ip_address = false
  key_name = "${var.key_name}"
  vpc_security_group_ids = [ "${aws_security_group.sg_kubemaster.id}" ]
  source_dest_check = "true"
  user_data = "${data.template_file.bootstrap_master.rendered}"
  tags = {
    Name = "${var.master_node_hostname}"
  }
}

# ---------------------------------------------
# Copy the token and discovery hash from master
# ---------------------------------------------

resource "null_resource" "copy_token_hash" {
  depends_on = [
    "aws_instance.kube_master"
  ]

  triggers {
    ip_address = "${aws_instance.kube_master.private_ip}"
  }

  connection {
    agent       = false
    bastion_user = "${var.ssh_user}"
    bastion_host = "${var.bastion_host}"
    bastion_private_key = "${file("${var.private_key_path}")}"
    timeout     = "3m"
    user = "${var.ssh_user}"
    host = "${aws_instance.kube_master.private_ip}"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source = "${path.module}/scripts/wait_for_master.bash"
    destination = "/tmp/wait_for_master.bash"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/wait_for_master.bash",
      "/tmp/wait_for_master.bash 600 10"
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.public_key_path} ubuntu@${aws_instance.kube_master.private_ip}:/tmp/.kubeadm_* /tmp/."
  }
}

# -------------------
# Create worker nodes
# -------------------

data "template_file" "bootstrap_worker" {
  template = "${file("${path.module}/templates/bootstrap-worker.bash.tpl")}"
  vars {
    kubernetes_version="${var.kubernetes_version}"
  }
}

data "template_file" "kubeadm_join" {
  template = "${file("${path.module}/templates/kubeadm_join.bash.tpl")}"
  vars {
    master_host = "${aws_instance.kube_master.private_ip}",
    master_port = "6443"
  }
}

resource "aws_instance" "kube_worker" {
  count = "${var.worker_nodes_count}"
  ami = "${var.ami}"
  instance_type = "t3.small"
  subnet_id = "${element(var.private_subnet_ids, count.index % length(var.private_subnet_ids))}"
  associate_public_ip_address = false
  key_name = "${var.key_name}"
  vpc_security_group_ids = [ "${aws_security_group.sg_kubeworker.id}" ]
  source_dest_check = "true"
  user_data = "${data.template_file.bootstrap_worker.rendered}"
  tags = {
    Name = "${var.worker_node_hostname}-${count.index}"
  }

  connection {
    agent = false
    bastion_user = "${var.ssh_user}"
    bastion_host = "${var.bastion_host}"
    bastion_private_key = "${file("${var.private_key_path}")}"
    timeout = "3m"
    user = "${var.ssh_user}"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    content = "${data.template_file.kubeadm_join.rendered}"
    destination = "/tmp/kubeadm_join.bash"
  }
}

# ---------------------------------------------
# Push token and discovery hash to worker nodes
# ---------------------------------------------

resource "null_resource" "push_token_hash" {
  depends_on = [
    "aws_instance.kube_worker",
    "null_resource.copy_token_hash"
  ]

  triggers {
    ip_address = "${join(",", aws_instance.kube_worker.*.private_ip)}"
  }

  count = "${var.worker_nodes_count}"

  connection {
    agent = false
    bastion_user = "${var.ssh_user}"
    bastion_host = "${var.bastion_host}"
    bastion_private_key = "${file("${var.private_key_path}")}"
    timeout = "3m"
    user = "${var.ssh_user}"
    host = "${element(aws_instance.kube_worker.*.private_ip, count.index)}"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source = "/tmp/.kubeadm_token"
    destination = "/tmp/.kubeadm_token"
  }

  provisioner "file" {
    source = "/tmp/.kubeadm_hash"
    destination = "/tmp/.kubeadm_hash"
  }
}

output "kube-master" {
  value = "${aws_instance.kube_master.private_ip}"
}

output "kube-workers" {
  value = "${aws_instance.kube_worker.*.private_ip}"
}
