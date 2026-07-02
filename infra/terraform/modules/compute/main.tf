# ============================================
# AMI (Ubuntu 22.04 LTS)
# ============================================
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# ============================================
# CONTROL PLANE NODE
# ============================================

resource "aws_instance" "control_plane" {
  count = var.node_count.control_plane

  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.security_group_id]

  # Use public IP for internet access
  associate_public_ip_address = true

  #   ssm agent
  iam_instance_profile = var.iam_instance_profile


  tags = {
    Name        = "${var.project_name}-${var.environment}-control-plane"
    Environment = var.environment
    Role        = "control-plane"
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# WORKER NODES
# ============================================

resource "aws_instance" "workers" {
  count = var.node_count.workers

  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = true

  #   ssm agent
  iam_instance_profile = var.iam_instance_profile

  tags = {
    Name        = "${var.project_name}-${var.environment}-worker-${count.index + 1}"
    Environment = var.environment
    Role        = "worker"
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# K3S TOKEN
# ============================================

# We still generate the token here so the Ansible inventory file can consume it
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# ============================================
# OUTPUTS
# ============================================

output "control_plane_public_ips" {
  value = aws_instance.control_plane[*].public_ip
}

output "control_plane_private_ips" {
  value = aws_instance.control_plane[*].private_ip
}

output "worker_public_ips" {
  value = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  value = aws_instance.workers[*].private_ip
}

output "k3s_token" {
  value     = random_password.k3s_token.result
  sensitive = true
}
