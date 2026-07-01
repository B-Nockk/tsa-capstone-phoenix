# ============================================
# SECURITY GROUPS
# ============================================

# Main security group for all nodes
resource "aws_security_group" "nodes" {
  name        = "${var.project_name}-${var.environment}-nodes"
  description = "Security group for TaskApp nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nodes-sg"
    Environment = var.environment
  }
}

# ============================================
# INBOUND RULES
# ============================================

# SSH - only from allowed IPs
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_ips
  security_group_id = aws_security_group.nodes.id
  description       = "SSH from admin IPs"
}

# HTTP - world accessible
resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "HTTP from anywhere"
}

# HTTPS - world accessible
resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "HTTPS from anywhere"
}

# Kubernetes API - only from VPC AND Admin IPs
resource "aws_security_group_rule" "k8s_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = concat([var.vpc_cidr], var.allowed_ssh_ips)
  security_group_id = aws_security_group.nodes.id
  description       = "Kubernetes API (VPC + Admin IP)"
}

# Node-to-node communication (internal)
resource "aws_security_group_rule" "node_internal" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.nodes.id
  description       = "Internal node communication"
}

# ============================================
# OUTBOUND RULES (allow all)
# ============================================

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "Allow all outbound"
}

# ============================================
# OUTPUTS
# ============================================

output "security_group_id" {
  value = aws_security_group.nodes.id
}
