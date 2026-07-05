# ============================================
# PROVIDER
# ============================================

provider "aws" {
  region = var.aws_region
}

# Dynamically fetch available AZs for the current region
data "aws_availability_zones" "available" {
  state = "available"
}
# ============================================
# SSH KEY MANAGEMENT (Optimized for CI/CD)
# ============================================

# Generate SSH key pair locally if it doesn't exist (Local Dev only)
resource "tls_private_key" "ssh" {
  count     = var.generate_ssh_key && var.ssh_public_key_content == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "null_resource" "ssh_dir" {
  count = var.generate_ssh_key ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p $(dirname ${var.ssh_public_key_path})"
  }
}

resource "local_file" "ssh_private" {
  count           = var.generate_ssh_key && var.ssh_public_key_content == "" ? 1 : 0
  content         = tls_private_key.ssh[0].private_key_openssh
  filename        = var.ssh_private_key_path
  file_permission = "0600"

  depends_on = [null_resource.ssh_dir]
}

resource "local_file" "ssh_public" {
  count           = var.generate_ssh_key && var.ssh_public_key_content == "" ? 1 : 0
  content         = tls_private_key.ssh[0].public_key_openssh
  filename        = var.ssh_public_key_path
  file_permission = "0644"

  depends_on = [null_resource.ssh_dir]
}

# Native AWS Key Pair resource
# If CI/CD passes the string, use it. Otherwise, read the local file.
resource "aws_key_pair" "capstone" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key_content != "" ? var.ssh_public_key_content : file(var.ssh_public_key_path)

  # Ensure the local file exists first if we are generating it
  depends_on = [local_file.ssh_public]
}

# ============================================
# NETWORK MODULE
# ============================================

module "network" {
  source = "./modules/network"

  environment          = var.environment
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region

  # use dynamically fetched zones instead of a hardcoded variable
  availability_zones = data.aws_availability_zones.available.names
}

# ============================================
# SECURITY MODULE
# ============================================

module "security" {
  source = "./modules/security"

  environment     = var.environment
  project_name    = var.project_name
  vpc_id          = module.network.vpc_id
  vpc_cidr        = var.vpc_cidr
  allowed_ssh_ips = var.allowed_ssh_ips
}

# ============================================
# COMPUTE MODULE
# ============================================

module "compute" {
  source = "./modules/compute"

  environment  = var.environment
  project_name = var.project_name

  #   instance_type               = var.instance_type
  control_plane_instance_type = coalesce(var.control_plane_instance_type, var.instance_type)
  worker_instance_type        = coalesce(var.worker_instance_type, var.instance_type)

  node_count        = var.node_count
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.security.security_group_id
  ssh_key_name      = aws_key_pair.capstone.key_name
  k3s_version       = var.k3s_version
  aws_region        = var.aws_region

  # ssm
  iam_instance_profile = var.enable_ssm ? aws_iam_instance_profile.ssm[0].name : null
}

# ============================================
# ANSIBLE INVENTORY GENERATION
# ============================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    control_plane_public_ips  = module.compute.control_plane_public_ips
    control_plane_private_ips = module.compute.control_plane_private_ips
    worker_public_ips         = module.compute.worker_public_ips
    worker_private_ips        = module.compute.worker_private_ips
    environment               = var.environment
    ssh_user                  = "ubuntu"
    ssh_private_key_path      = var.ssh_private_key_path
    k3s_token                 = module.compute.k3s_token
    vpc_cidr                  = var.vpc_cidr
    k3s_pod_cidr              = var.k3s_pod_cidr
    k3s_service_cidr          = var.k3s_service_cidr
  })

  filename = "${path.module}/../ansible/inventory/${var.environment}/hosts.ini"

  depends_on = [module.compute]
}

# ============================================
# OUTPUTS
# ============================================

output "control_plane_public_ips" {
  value = module.compute.control_plane_public_ips
}

output "control_plane_private_ips" {
  value = module.compute.control_plane_private_ips
}

output "worker_public_ips" {
  value = module.compute.worker_public_ips
}

output "worker_private_ips" {
  value = module.compute.worker_private_ips
}

output "ssh_key_name" {
  value = aws_key_pair.capstone.key_name
}

output "ssh_private_key_path" {
  value = var.ssh_private_key_path
}

output "ssh_command" {
  value = "ssh -i ${var.ssh_private_key_path} ubuntu@${module.compute.control_plane_public_ips[0]}"
}

output "kubeconfig_command" {
  value = <<-EOT
    # Get kubeconfig:
    scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ubuntu@${module.compute.control_plane_public_ips[0]}:/etc/rancher/k3s/k3s.yaml ./kubeconfig-${var.environment}.yaml
    sed -i 's/127.0.0.1/${module.compute.control_plane_public_ips[0]}/g' ./kubeconfig-${var.environment}.yaml
    export KUBECONFIG=./kubeconfig-${var.environment}.yaml
    kubectl get nodes
  EOT
}

output "ansible_inventory_path" {
  value = local_file.ansible_inventory.filename
}

# ============================================
# DATABASE BACKUPS (S3)
# ============================================
# Fetch the AWS Account ID dynamically to ensure the bucket name is globally unique
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "db_backups" {
  bucket        = "${var.project_name}-backups-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-db-backups"
    Environment = var.environment
  }
}

# Output the exact bucket name so we can use it
output "db_backup_bucket_name" {
  value = aws_s3_bucket.db_backups.bucket
}
