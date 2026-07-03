# ============================================
# SSH KEY CONFIGURATION
# ============================================

variable "ssh_key_name" {
  description = "Name of the SSH key pair in AWS"
  type        = string
  default     = "tsa-capstone-project"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/tsa-capstone/tsa-capstone-project.pub"
}

variable "ssh_public_key_content" {
  description = "The actual public key string (optional, overrides file path)"
  type        = string
  default     = ""
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  default     = "~/.ssh/tsa-capstone/tsa-capstone-project"
}

variable "generate_ssh_key" {
  description = "Generate SSH key pair if it doesn't exist"
  type        = bool
  default     = false
}

# ============================================
# ENVIRONMENT CONFIGURATION
# ============================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "tsa-capstone"
}

# ============================================
# AWS CONFIGURATION
# ============================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# variable "availability_zones" {
#   description = "Availability zones for HA"
#   type        = list(string)
#   default     = ["us-east-1a", "us-east-1b"]
# }

# ============================================
# COMPUTE CONFIGURATION (AWS Free Tier)
# ============================================

variable "instance_type" {
  description = "Fallback EC2 instance type for all nodes if specific ones aren't provided"
  type        = string
  default     = "t3.micro"
}

variable "control_plane_instance_type" {
  description = "Specific instance type for the control plane. Falls back to instance_type if empty."
  type        = string
  default     = "t3.small"
}

variable "worker_instance_type" {
  description = "Specific instance type for worker nodes. Falls back to instance_type if empty."
  type        = string
  default     = ""
}

variable "node_count" {
  description = "Number of nodes"
  type = object({
    control_plane = number
    workers       = number
  })
  default = {
    control_plane = 1
    workers       = 2
  }
}

# ============================================
# NETWORK CONFIGURATION
# ============================================

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ============================================
# SECURITY CONFIGURATION
# ============================================

variable "allowed_ssh_ips" {
  description = "IPs allowed to SSH (CIDR blocks)"
  type        = list(string)
  default     = [] # MUST be overridden!
}

# ============================================
# K3S CONFIGURATION
# ============================================

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.28.8+k3s1"
}

# ============================================
# DOMAIN CONFIGURATION
# ============================================

variable "domain_name" {
  description = "Domain name for the application (e.g., taskapp.example.com)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID (if using AWS Route53)"
  type        = string
  default     = ""
}

# ============================================
# STATE MANAGEMENT
# ============================================

variable "enable_remote_state" {
  description = "Enable remote state (S3 + DynamoDB)"
  type        = bool
  default     = false
}

variable "state_bucket_name" {
  description = "S3 bucket name for remote state"
  type        = string
  default     = ""
}

variable "state_lock_table" {
  description = "DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "enable_ssm" {
  description = "Attach IAM instance profile + install SSM agent for out-of-band access"
  type        = bool
  default     = true
}

variable "ssm_role_name" {
  description = "Name for the SSM IAM role"
  type        = string
  default     = "tsa-capstone-ssm-role"
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "api_allowed_ips" {
  description = "List of IPs allowed to access the K8s API"
  type        = list(string)
  default     = []
}

# ============================================
# KUBERNETES NETWORKING
# ============================================
variable "k3s_pod_cidr" {
  description = "CIDR block for Kubernetes Pods"
  type        = string
  default     = "192.168.0.0/16"
}

variable "k3s_service_cidr" {
  description = "CIDR block for Kubernetes Services"
  type        = string
  default     = "10.43.0.0/16"
}
