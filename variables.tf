variable "project" {
  description = "Project name/prefix for tags and resource names"
  type        = string
  default     = "interview"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs (AZ0, AZ1)"
  type        = list(string)
  default = [
    "10.0.0.0/24",
    "10.0.1.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "Two private subnet CIDRs (AZ0, AZ1)"
  type        = list(string)
  default = [
    "10.0.10.0/24",
    "10.0.11.0/24"
  ]
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR (for SSH). e.g., 203.0.113.5/32"
  type        = string
  default     = "169.150.188.81/32" # change to your IP for better security
}

variable "ec2_instance_type" {
  description = "EC2 instance type (free tier eligible: t2.micro in many regions)"
  type        = string
  default     = "t2.micro"
}

variable "ec2_key_name" {
  description = "Optional EC2 key pair name for SSH"
  type        = string
  default     = null
}

variable "db_name" {
  description = "Initial Postgres DB name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Postgres master username"
  type        = string
  default     = "appuser"
}

variable "rds_instance_class" {
  description = "Free-tier eligible RDS instance class (e.g., db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_engine_version" {
  description = "Postgres engine version (AWS-supported string, e.g., 15)"
  type        = string
  default     = "15"
}

variable "redis_node_type" {
  description = "Free-tier eligible Redis node type (e.g., cache.t3.micro)"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version (e.g., 7.1)"
  type        = string
  default     = "7.1"
}

# ── Additional global variables ───────────────────────────────
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ssh_cidrs" {
  description = "Optional list of CIDR blocks allowed for SSH. If empty, falls back to my_ip_cidr."
  type        = list(string)
  default     = []
}

variable "db_password" {
  description = "Master DB password. If null/empty, Terraform will generate one."
  type        = string
  sensitive   = true
  default     = null
}
