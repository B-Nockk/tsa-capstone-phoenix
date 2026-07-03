variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "IPs allowed to SSH"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "api_allowed_ips" {
  description = "List of IPs allowed to access the K8s API"
  type        = list(string)
  default     = []
}
