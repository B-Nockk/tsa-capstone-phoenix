variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "node_count" {
  description = "Number of nodes"
  type = object({
    control_plane = number
    workers       = number
  })
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for nodes"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "k3s_version" {
  description = "K3s version"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ssh_key_name" {
  description = "SSH key pair name in AWS"
  type        = string
}

# ssm agent
variable "iam_instance_profile" {
  type    = string
  default = null
}
